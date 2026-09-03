EDC/RWDデータの異常検知結果をレビューしてください。

目的:
- RBQM / Central Monitoring / Data Quality Review のための優先順位付け

入力:
- study_id: {{study_id}}
- batch_id: {{batch_id}}
- anomaly_results: {{anomaly_results_json}}

出力してほしい内容:
1. 重大度別の要約
2. 上位異常候補の解釈
3. rule evidence と model evidence の分離
4. data management / central monitoring / biostatistics の推奨アクション
5. 誤検知・医学的妥当性・site差の可能性
6. 監査証跡上、保存すべき情報
