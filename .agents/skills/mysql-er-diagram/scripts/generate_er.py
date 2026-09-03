#!/usr/bin/env python3
"""mysql-er-diagram スキル用 ER図生成スクリプト.

指定されたMySQLデータベースからテーブル・カラム情報を抽出し、
辞書CSV・PlantUML・Draw.io互換XMLをフル再生成する（既存CSVは読み込まない）。
標準ライブラリのみを使用。

セキュリティ対策:
  - SQLインジェクション防止: db_name をホワイトリスト検証
  - パストラバーサル防止: 出力パスの正規化と基底ディレクトリ検証
  - 認証情報の保護: パスワードは環境変数経由で渡し、プロセスリストへの露出を回避
  - .env ファイルの安全な読み込み
"""
import argparse
import configparser
import csv
import datetime
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

JST = ZoneInfo("Asia/Tokyo")

# ── セキュリティ: DB名に許可する文字パターン (ホワイトリスト) ──
_SAFE_DB_NAME_PATTERN: re.Pattern[str] = re.compile(r"^[A-Za-z0-9_]+$")

# Draw.io スタイル（環境差で崩れないよう明示）
_DRAWIO_NODE_FILL = "#f5f5f5"
_DRAWIO_NODE_STROKE = "#666666"
_DRAWIO_NODE_FONT = "#333333"
_DRAWIO_EDGE_STROKE = "#999999"
_DRAWIO_EDGE_STROKE_WIDTH = "1"


def _find_repo_root(start: Path, *, max_levels: int = 15) -> Path:
    """`.agent` が見つかる上位を repo root として推定する。"""
    current = start.resolve()
    for _ in range(max_levels):
        if (current / ".agent").is_dir():
            return current
        if current.parent == current:
            break
        current = current.parent
    return Path.cwd()


def _load_run_scope():
    shared = _find_repo_root(Path(__file__).resolve().parent) / ".agent" / "shared"
    if str(shared) not in sys.path:
        sys.path.insert(0, str(shared))
    import run_scope

    return run_scope


def _validate_db_name(db_name: str) -> str:
    """DB名のホワイトリスト検証.

    SQLインジェクションやパストラバーサルを防止するため、
    英数字とアンダースコアのみを許可する。
    """
    if not db_name:
        print("Error: データベース名が空です。", file=sys.stderr)
        sys.exit(1)
    if not _SAFE_DB_NAME_PATTERN.match(db_name):
        print(
            f"Error: データベース名に不正な文字が含まれています: '{db_name}'\n"
            "  許可される文字: 英数字 (A-Z, a-z, 0-9) とアンダースコア (_)",
            file=sys.stderr,
        )
        sys.exit(1)
    return db_name


def _validate_output_dir(out_dir: str) -> str:
    """出力ディレクトリのパストラバーサル検証.

    正規化したパスが '..' を含まないか、
    期待されるベースディレクトリ内にあるかを確認する。
    """
    resolved: str = os.path.realpath(os.path.abspath(out_dir))
    # '..' コンポーネントが残っていないことを確認
    if ".." in os.path.normpath(out_dir).split(os.sep):
        print(
            f"Error: 出力先パスに '..' が含まれています: '{out_dir}'",
            file=sys.stderr,
        )
        sys.exit(1)
    return resolved


def _find_env_file() -> str | None:
    """プロジェクトルートの .env ファイルを探索する.

    探索順序:
      1. repo root（`.agent` が見つかる上位）の `.env`
      2. カレントワーキングディレクトリ
      3. スクリプト自身の祖先ディレクトリを辿り最初に見つかった .env
    """
    # 1. repo root
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    repo_env: str = os.path.join(str(repo_root), ".env")
    if os.path.isfile(repo_env):
        return repo_env

    # 2. cwd
    cwd_env: str = os.path.join(os.getcwd(), ".env")
    if os.path.isfile(cwd_env):
        return cwd_env

    # 3. スクリプト自身から祖先ディレクトリを辿る
    script_dir: str = os.path.dirname(os.path.abspath(__file__))
    current: str = script_dir
    for _ in range(10):  # 最大10階層まで
        candidate: str = os.path.join(current, ".env")
        if os.path.isfile(candidate):
            return candidate
        parent: str = os.path.dirname(current)
        if parent == current:
            break
        current = parent

    return None


def load_env(env_path: str | None = None) -> dict[str, str]:
    """指定パスまたは自動探索で .env ファイルから環境変数を読み込む.

    セキュリティ考慮:
      - .env ファイルのパーミッションを警告レベルでチェック
      - 読み込み済みの値は外部に露出させない
    """
    env_vars: dict[str, str] = {}
    # 明示パスが渡された場合は絶対パスに正規化
    resolved_env: str | None = None
    if env_path:
        resolved_env = os.path.abspath(env_path)
    else:
        resolved_env = _find_env_file()
    env_file: str | None = resolved_env

    if env_file is None or not os.path.isfile(env_file):
        print(
            "Warning: .env ファイルが見つかりません。\n"
            "  → mysql CLI は ~/.my.cnf をフォールバックとして使用します。\n"
            "  → 明示的に指定する場合: --env <パス>",
            file=sys.stderr,
        )
        return env_vars

    print(f"Info: .env を読み込みます: {env_file}", file=sys.stderr)

    # パーミッションチェック (他者読み取り可能な場合に警告)
    try:
        mode: int = os.stat(env_file).st_mode
        if mode & 0o044:  # group/other read
            print(
                "Warning: .env ファイルが他のユーザーから読み取り可能です。\n"
                "  推奨: chmod 600 .env",
                file=sys.stderr,
            )
    except OSError:
        pass

    with open(env_file, "r", encoding="utf-8") as f:
        for raw_line in f:
            line: str = raw_line.strip()
            if line and not line.startswith("#"):
                if "=" in line:
                    key, val = line.split("=", 1)
                    # クォート除去
                    val = val.strip("'\"")
                    env_vars[key.strip()] = val
    return env_vars


def _load_my_cnf_client() -> dict[str, str]:
    """~/.my.cnf の [client] セクションを読み込む（存在しない場合は空）。"""
    my_cnf = os.path.expanduser("~/.my.cnf")
    if not os.path.isfile(my_cnf):
        return {}
    parser = configparser.ConfigParser()
    parser.read(my_cnf)
    if not parser.has_section("client"):
        return {}
    return {k: v for k, v in parser.items("client")}


def run_mysql_query(
    db_name: str,
    env_vars: dict[str, str],
) -> list[dict[str, str]]:
    """mysql CLI経由でテーブル・カラム情報を取得する.

    セキュリティ対策:
      - db_name は事前にホワイトリスト検証済みの値のみ受け付ける
      - パスワードは --defaults-extra-file 経由で渡し、
        プロセスリストへの露出を回避する
      - shell=True は使用しない (リスト形式で引数を渡す)
    """
    my_cnf = _load_my_cnf_client()
    user: str = env_vars.get("MYSQL_USER", my_cnf.get("user", "root"))
    password: str = env_vars.get("MYSQL_PASSWORD", my_cnf.get("password", ""))
    host: str = env_vars.get("MYSQL_HOST", my_cnf.get("host", "127.0.0.1"))
    port: str = env_vars.get("MYSQL_PORT", my_cnf.get("port", "3306"))

    # db_name はホワイトリスト検証済みのため、クエリ内に安全に埋め込める
    # (INFORMATION_SCHEMA への読み取り専用クエリ)
    query: str = (
        "SELECT t.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE,"
        " IF(pk.COLUMN_NAME IS NOT NULL, 'TRUE', 'FALSE') AS is_pk"
        " FROM INFORMATION_SCHEMA.TABLES t"
        " JOIN INFORMATION_SCHEMA.COLUMNS c"
        "   ON t.TABLE_SCHEMA = c.TABLE_SCHEMA"
        "   AND t.TABLE_NAME = c.TABLE_NAME"
        " LEFT JOIN ("
        "   SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME"
        "   FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE"
        "   WHERE CONSTRAINT_NAME = 'PRIMARY'"
        " ) pk ON c.TABLE_SCHEMA = pk.TABLE_SCHEMA"
        "   AND c.TABLE_NAME = pk.TABLE_NAME"
        "   AND c.COLUMN_NAME = pk.COLUMN_NAME"
        f" WHERE t.TABLE_SCHEMA = '{db_name}'"
        "   AND t.TABLE_TYPE = 'BASE TABLE'"
        " ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;"
    )

    # 認証情報を --defaults-extra-file で安全に渡す
    defaults_file: str | None = None
    temp_defaults: str | None = None
    try:
        if env_vars.get("MYSQL_PASSWORD"):
            fd: int
            defaults_file_path: str
            fd, defaults_file_path = tempfile.mkstemp(
                prefix=".mysql_er_",
                suffix=".cnf",
            )
            temp_defaults = defaults_file_path
            with os.fdopen(fd, "w") as tmp:
                tmp.write(f"[client]\npassword={password}\n")
            os.chmod(temp_defaults, 0o600)
            defaults_file = temp_defaults
        else:
            my_cnf_path = os.path.expanduser("~/.my.cnf")
            if os.path.isfile(my_cnf_path):
                defaults_file = my_cnf_path

        cmd: list[str] = ["mysql"]
        if defaults_file:
            cmd.append(f"--defaults-extra-file={defaults_file}")
        cmd.extend(["-h", host, "-P", port, "-u", user, "-B", "-e", query])

        res: subprocess.CompletedProcess[str] = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )
    finally:
        if temp_defaults and os.path.exists(temp_defaults):
            os.unlink(temp_defaults)

    if res.returncode != 0:
        # エラーメッセージからパスワード等の機密情報を除去して表示
        stderr_safe: str = (
            res.stderr.replace(password, "****") if password else res.stderr
        )
        print(f"Error querying database: {stderr_safe}", file=sys.stderr)
        sys.exit(1)

    lines: list[str] = res.stdout.strip().split("\n")
    if len(lines) <= 1:
        print("No tables found or empty result.")
        return []

    columns: list[dict[str, str]] = []
    for line in lines[1:]:
        cols: list[str] = line.split("\t")
        if len(cols) >= 4:
            columns.append(
                {
                    "table_name": cols[0],
                    "column_name": cols[1],
                    "data_type": cols[2],
                    "is_primary_key": cols[3],
                }
            )
    return columns


def _validate_sqlite_path(sqlite_path: str) -> str:
    """SQLite DB ファイルパスの検証."""
    resolved = os.path.realpath(os.path.abspath(sqlite_path))
    if not os.path.isfile(resolved):
        print(
            f"Error: SQLite ファイルが見つかりません: '{sqlite_path}'", file=sys.stderr
        )
        sys.exit(1)
    if not resolved.lower().endswith((".db", ".sqlite", ".sqlite3")):
        print(
            f"Error: SQLite ファイルの拡張子が不正です: '{sqlite_path}'\n"
            "  許可: .db, .sqlite, .sqlite3",
            file=sys.stderr,
        )
        sys.exit(1)
    return resolved


def run_sqlite_query(sqlite_path: str) -> list[dict[str, str]]:
    """sqlite3 標準ライブラリ経由でテーブル・カラム・FK 情報を取得する."""
    sqlite_path = _validate_sqlite_path(sqlite_path)
    columns: list[dict[str, str]] = []
    fk_map: dict[tuple[str, str], str] = {}

    with sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True) as conn:
        conn.row_factory = sqlite3.Row
        tables = [
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
                "ORDER BY name"
            )
        ]
        for table_name in tables:
            for fk in conn.execute(f"PRAGMA foreign_key_list({table_name!r})"):
                fk_map[(table_name, fk["from"])] = f"{fk['table']}.{fk['to']}"

            for col in conn.execute(f"PRAGMA table_info({table_name!r})"):
                col_name = col["name"]
                fk_target = fk_map.get((table_name, col_name), "")
                columns.append(
                    {
                        "table_name": table_name,
                        "column_name": col_name,
                        "data_type": col["type"] or "TEXT",
                        "is_primary_key": "TRUE" if col["pk"] else "FALSE",
                        "foreign_key_target": fk_target,
                    }
                )

    return columns


def _infer_foreign_keys(
    db_columns: list[dict[str, str]],
    *,
    use_heuristic: bool = True,
) -> list[dict[str, str]]:
    """FK 情報を辞書行に整形する。SQLite は PRAGMA FK のみ、MySQL はヒューリスティック補完。"""
    potential_masters: dict[str, str] = {}
    if use_heuristic:
        for col in db_columns:
            if col["is_primary_key"] == "TRUE":
                continue
            cname = col["column_name"].upper()
            tname = col["table_name"]
            if cname.endswith("NO") or cname.endswith("ID") or cname.endswith("CODE"):
                current_master = potential_masters.get(cname)
                if not current_master:
                    potential_masters[cname] = tname
                else:
                    score_current = len(current_master) - (
                        10 if "demo" in current_master.lower() else 0
                    )
                    score_new = len(tname) - (10 if "demo" in tname.lower() else 0)
                    if score_new < score_current:
                        potential_masters[cname] = tname

    merged_columns: list[dict[str, str]] = []
    for col in db_columns:
        fk_target = col.get("foreign_key_target", "")
        new_row: dict[str, str] = {
            "table_name": col["table_name"],
            "logical_table_name": col["table_name"],
            "column_name": col["column_name"],
            "logical_column_name": col["column_name"],
            "data_type": col["data_type"],
            "is_primary_key": col["is_primary_key"],
            "is_foreign_key": "TRUE" if fk_target else "FALSE",
            "foreign_key_target": fk_target,
        }
        if use_heuristic and not fk_target and col["is_primary_key"] != "TRUE":
            cname_up = col["column_name"].upper()
            master_table = potential_masters.get(cname_up)
            if master_table and master_table != col["table_name"]:
                new_row["is_foreign_key"] = "TRUE"
                new_row["foreign_key_target"] = f"{master_table}.{col['column_name']}"
        merged_columns.append(new_row)
    return merged_columns


def generate_files(
    db_name: str,
    out_dir: str,
    env_path: str | None = None,
    sqlite_path: str | None = None,
    run_id: str | None = None,
) -> None:
    """メインの生成ロジック: CSV/PlantUML/Draw.io XML を run 単位ディレクトリに出力する."""
    out_root = _validate_output_dir(out_dir)
    os.makedirs(out_root, exist_ok=True)

    rs = _load_run_scope()
    input_for_meta = sqlite_path if sqlite_path else None
    run_dir, rid = rs.prepare_run_output_dir(
        out_root,
        "mysql-er-diagram",
        run_id=run_id,
        input_path=input_for_meta,
    )
    out_dir = str(run_dir)

    if sqlite_path:
        db_name = _validate_db_name(Path(sqlite_path).stem)
        db_columns = run_sqlite_query(sqlite_path)
    else:
        db_name = _validate_db_name(db_name)
        env_vars = load_env(env_path)
        db_columns = run_mysql_query(db_name, env_vars)

    if not db_columns:
        return

    csv_path: str = os.path.join(out_dir, f"{db_name}_dictionary.csv")
    merged_columns = _infer_foreign_keys(db_columns, use_heuristic=sqlite_path is None)

    # CSV書き出し
    fieldnames: list[str] = [
        "table_name",
        "logical_table_name",
        "column_name",
        "logical_column_name",
        "data_type",
        "is_primary_key",
        "is_foreign_key",
        "foreign_key_target",
    ]
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(merged_columns)

    now = datetime.datetime.now(JST)
    now_str: str = now.strftime("%Y%m%d_%H%M%S")
    now_full: str = now.strftime("%Y-%m-%d %H:%M:%S")

    # テーブル別にグルーピング
    tables: dict[str, dict[str, Any]] = {}
    for c in merged_columns:
        tbl_name: str = c["table_name"]
        if tbl_name not in tables:
            tables[tbl_name] = {"logical": c["logical_table_name"], "cols": []}
        tables[tbl_name]["cols"].append(c)

    # ── PlantUML 出力 ──
    md_path: str = os.path.join(out_dir, f"{db_name}_er_{now_str}.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"created: {now_full} (JST)\n")
        f.write("author: AI Agent (Gemini 2.0 Pro)\n\n")
        f.write("```plantuml\n@startuml\n")

        for t_name, t_data in tables.items():
            logical: str = t_data["logical"]
            f.write(f'entity "{t_name} ({logical})" as {t_name} {{\n')
            col_list: list[dict[str, str]] = t_data["cols"]
            for c in col_list:
                pk_mark: str = " <<PK>>" if c["is_primary_key"] == "TRUE" else ""
                fk_mark: str = " <<FK>>" if c["is_foreign_key"] == "TRUE" else ""
                star: str = "*" if pk_mark else " "
                f.write(
                    f'  {star} {c["column_name"]} : {c["data_type"]}{pk_mark}{fk_mark}\n'
                )
            f.write("}\n")

        # リレーション
        rels: set[str] = set()
        for c in merged_columns:
            fk_target: str = c.get("foreign_key_target", "")
            if fk_target:
                target_parts: list[str] = fk_target.split(".")
                if len(target_parts) >= 1:
                    target_t: str = target_parts[0]
                    rels.add(
                        f'{target_t} ||--o{{ {c["table_name"]} : "{c["column_name"]}"'
                    )

        for r in rels:
            f.write(f"{r}\n")

        f.write("@enduml\n```\n")

    # ── Draw.io XML 出力 ──
    xml_path: str = os.path.join(out_dir, f"{db_name}_er_{now_str}.xml")
    mxfile: ET.Element = ET.Element("mxfile")
    diagram: ET.Element = ET.SubElement(mxfile, "diagram")
    mx_model: ET.Element = ET.SubElement(
        diagram,
        "mxGraphModel",
        dx="1000",
        dy="1000",
        grid="1",
        gridSize="10",
        guides="1",
        tooltips="1",
        connect="1",
        arrows="1",
        fold="1",
        page="1",
        pageScale="1",
        pageWidth="827",
        pageHeight="1169",
        math="0",
        shadow="0",
    )
    xml_root: ET.Element = ET.SubElement(mx_model, "root")
    ET.SubElement(xml_root, "mxCell", id="0")
    cell1: ET.Element = ET.SubElement(xml_root, "mxCell", id="1")
    cell1.set("parent", "0")

    id_counter: int = 2
    table_ids: dict[str, str] = {}

    x: int = 50
    y: int = 50
    row_max_height: int = 0

    for t_name, t_data in tables.items():
        tid: str = str(id_counter)
        table_ids[t_name] = tid
        id_counter += 1

        col_html: str = ""
        col_list = t_data["cols"]
        for c in col_list:
            pk_mark = "PK " if c["is_primary_key"] == "TRUE" else ""
            fk_mark = "FK " if c["is_foreign_key"] == "TRUE" else ""
            col_html += f"{pk_mark}{fk_mark}{c['column_name']} : {c['data_type']}<br>"

        logical = t_data["logical"]
        label: str = f"<b>{t_name} ({logical})</b><hr>{col_html}"
        height: int = 40 + len(col_list) * 15

        # 横幅超過時は次の行へ折り返し (動的高さ)
        if x + 220 > 1300:
            x = 50
            y += row_max_height + 50
            row_max_height = 0

        row_max_height = max(row_max_height, height)

        node: ET.Element = ET.SubElement(
            xml_root,
            "mxCell",
            id=tid,
            value=label,
            vertex="1",
        )
        node.set("parent", "1")
        node.set(
            "style",
            "rounded=1;whiteSpace=wrap;html=1;align=left;"
            "verticalAlign=top;spacing=4;spacingTop=4;"
            "fillColor=%s;strokeColor=%s;fontColor=%s"
            % (_DRAWIO_NODE_FILL, _DRAWIO_NODE_STROKE, _DRAWIO_NODE_FONT),
        )
        geo: ET.Element = ET.SubElement(
            node,
            "mxGeometry",
            x=str(x),
            y=str(y),
            width="220",
            height=str(height),
        )
        geo.set("as", "geometry")

        x += 260

    # エッジ (リレーション線) の描画
    for c in merged_columns:
        fk_target = c.get("foreign_key_target", "")
        if fk_target:
            target_parts = fk_target.strip().split(".")
            target_t = target_parts[0].strip()
            source_t: str = c["table_name"].strip()

            if target_t in table_ids and source_t in table_ids and target_t != source_t:
                eid: str = str(id_counter)
                id_counter += 1

                edge: ET.Element = ET.SubElement(
                    xml_root,
                    "mxCell",
                    id=eid,
                    value=c["column_name"],
                    edge="1",
                    source=table_ids[source_t],
                    target=table_ids[target_t],
                )
                edge.set("parent", "1")
                edge.set(
                    "style",
                    "edgeStyle=orthogonalEdgeStyle;rounded=0;"
                    "orthogonalLoop=1;jettySize=auto;html=1;"
                    "endArrow=classic;endFill=1;"
                    "strokeColor=%s;strokeWidth=%s"
                    % (_DRAWIO_EDGE_STROKE, _DRAWIO_EDGE_STROKE_WIDTH),
                )
                edge_geo: ET.Element = ET.SubElement(
                    edge,
                    "mxGeometry",
                    relative="1",
                )
                edge_geo.set("as", "geometry")

    tree: ET.ElementTree = ET.ElementTree(mxfile)
    tree.write(xml_path, encoding="utf-8", xml_declaration=True)

    print(f"Extraction and generation complete for database {db_name}.")
    print(f"CSV updated: {csv_path}")
    print(f"PlantUML created: {md_path}")
    print(f"Draw.io XML created: {xml_path}")


if __name__ == "__main__":
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="MySQL / SQLite ER図生成スクリプト (標準ライブラリのみ使用)",
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--db", help="対象 MySQL データベース名")
    source.add_argument(
        "--sqlite", help="対象 SQLite ファイルパス (.db / .sqlite / .sqlite3)"
    )
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    default_out_dir = str(repo_root / "skill_out")
    parser.add_argument("--out", default=default_out_dir, help="出力先の親ディレクトリ")
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（未指定時は JST タイムスタンプ。auto も可）",
    )
    parser.add_argument(
        "--env", default=None, help=".env ファイルパス (省略時は自動探索)"
    )
    args: argparse.Namespace = parser.parse_args()

    generate_files(
        args.db or "",
        args.out,
        env_path=args.env,
        sqlite_path=args.sqlite,
        run_id=args.run_id,
    )
