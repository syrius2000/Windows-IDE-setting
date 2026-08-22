# オフライン・インタラクティブQuarto報告書

## 背景と目的（Why）

現在のCase Projectでは、Quartoによる静的HTML、PDF、PowerPointなどを生成できますが、医師や共同研究者がブラウザ上で条件を切り替えながら集計結果を確認するための標準報告書がありません。そこで、Python/R/DuckDBで事前に集計・開示統制したデータを、QuartoのObservable JS（OJS）およびObservable Plotを用いたブラウザ内のインタラクティブ報告書として共有できる能力を追加します。

この報告書は、閲覧者側にPython、R、MySQL接続環境を要求せず、院内またはオフライン環境で外部通信を発生させずに利用できることを目標とします。個票や未加工の機微データはブラウザへ渡さず、既存の`outputs/private/`と`outputs/release/`の境界および`release-manifest.yml`による人手承認を維持します。

## 変更内容（What Changes）

- Case Projectに、共同研究者向けインタラクティブQuarto報告書の標準テンプレート（`reports/quarto/interactive_summary.qmd`）を追加する。
- Python/R/DuckDB側で、ブラウザへ渡してよい事前集計・小セル抑制（<5マスキング）済みJSONデータを生成する。
- Quarto標準のObservable JS（OJS）＋Observable Plotを用い、インライン埋め込み（`embed-resources: true`）による完全自己完結HTMLを構成する。
- 報告書で、期間、群、性別などの許可された集計条件を動的にフィルタリングできるようにする。
- 集計表、グラフ、注記を閲覧者がクリック操作で切り替えられるようにする。
- 小セル抑制、丸め、識別子除去、出力列の許可リスト検査を配布前の安全ゲートにする。
- 生成物にCDN、外部画像、外部フォント、外部APIへの送信処理を含めず、完全オフライン動作を保証する。
- Windows 11のEdgeおよびChromeで、ダブルクリック（`file://`）起動による表示、フィルタ、グラフ変更を検証する。
- ブラウザの厳格なポリシー制限環境向けに、外部通信を行わない`127.0.0.1`ローカルHTTPプレビュー機能（Cursorタスク）を提供する。
- インタラクティブ方式を利用しない場合でも、従来のQuarto静的HTMLを生成できるフォールバックを維持する。
- 実データを用いた公開報告書の生成、外部サーバーへのアップロード、DuckDB-WASMによる任意SQL実行機能は本Changeの必須スコープに含めない。

## 能力（Capabilities）

### 新規能力

- `interactive-offline-reporting`: 事前集計・開示統制済みデータを用い、Quarto OJSおよびObservable Plotによって外部通信なし・`file://`ダブルクリックでブラウザ内のフィルタリングとグラフ表示切替を行える自己完結型インタラクティブ報告書を提供する。

### 既存能力の変更

- なし。既存の`analysis-project-governance`および`analysis-project-factory`の要件は変更せず、新能力が既存のデータ境界、開示統制、Case Project構造に適合するようにする。

## 影響範囲（Impact）

- **テンプレート**: `templates/analysis-project/template/reports/quarto/interactive_summary.qmd`、関連する設定・サンプルデータ・タスク定義。
- **生成・検査スクリプト**: インタラクティブ報告書の生成、自己完結性検査、外部URL・外部通信検査、機微データ混入検査。
- **依存関係**: Quarto CLI標準機能（Quarto内包OJSエンジン）を活用し、余分なフロントエンドnpmパッケージの常時依存を回避。
- **テスト**: Case Project生成後の報告書生成、HTML自己完結性、開示統制、禁止データ混入、外部通信ゼロの検証。
- **ドキュメント**: README、初心者向けチートシート、日常運用マニュアル、共同研究者向け閲覧・配布手順。
- **ブラウザ実行環境**: Windows 11のMicrosoft EdgeおよびGoogle Chromeを主要な受入対象とする。
- **セキュリティ境界**: ブラウザへ渡すデータは合成データまたは開示統制済み集計データに限定し、個票・直接識別子・認証情報・自由記載を含めない。
- **互換性**: 既存の静的Quarto HTML、PDF、PowerPoint、Slidev出力およびSAS CP932領域には破壊的変更を加えない。
