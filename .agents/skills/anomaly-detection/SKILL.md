---
name: anomaly-detection
description: Use when reviewing EDC/RWD, RBQM, central monitoring, audit trail, query log, or site-level indicators for anomaly or outlier signals.
license: MIT
metadata:
  author: Yamaguchi Manabu
  version: "0.2.0"
---

# EDC/RWD Anomaly Detection Skill

EDC/eCRF export や RWD/eSource データ、監査証跡、query log、site-level risk indicator を対象に、ルールベース、robust statistics、Isolation Forest、LOF、MCD（ロバストマハラノビス距離）、STL（時系列分解）、PSI/KS（分布シフト）、LLM review を組み合わせて異常候補を優先順位付けするAIエージェントSkillです。

詳細な設計と運用手順は、同階層の [README.md](README.md) と `docs/` を参照してください。

## 主要な入口

- Python entrypoint: `anomaly_detection.pipeline:run_detection`
- CLI（推奨）: スキル直下で `uv run python -m anomaly_detection.cli --input <path>`（`--output` 未指定時は `--output-root` 配下の `run_<id>/` に出力）
- 自動セットアップ: `python3 scripts/setup_env.py` (または `make setup`)
- セルフヘルスチェック: `uv run python scripts/check_health.py` (または `make health`)
- ラッパー: `scripts/infer.py`
- 設定: `configs/`
- スキーマ: `docs/schemas/output.schema.json` (v0.2.0)

## 注意事項

- 本スキルは異常の確定ではなく、レビュー優先順位付けを目的とします。
- 自動的な医療判断や query 発行は行いません。
- PHI/PII をログに出さず、監査可能な出力を残してください。
- `--output` 未指定時は `--output-root`（既定 `./skill_out/anomaly_detection`）配下の `run_<id>/anomaly_results.jsonl` に保存する。同一入力の再実行でも `--run-id` 未指定なら別 run ディレクトリに隔離される。
