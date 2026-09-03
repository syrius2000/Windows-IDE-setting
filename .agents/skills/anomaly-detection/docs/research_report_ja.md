# RWD/EDC対象 異常検知AIエージェントSkill 設計レポート

確認日: 2026-07-02 Asia/Tokyo  
対象ディレクトリ: `Repos/.agent/anomaly-detection/`

## 要点

- 初期本番では、**ルールベース + robust statistics + Isolation Forest + LOF** を推奨する。
- AutoEncoder, LSTM, Transformer, Bayesian anomaly detection, EVT は拡張候補だが、初期導入では検証・説明・監査負荷が高い。
- EDC/RWDでは「値の外れ」だけでは不十分で、**欠損、重複、時系列矛盾、audit trail、query log、site drift、provenance anomaly** を同時に扱う必要がある。
- Skillは「異常確定」ではなく、**review queue の優先順位付け**として切るべきである。

## 事実

EDC/RWDの品質管理では、ICH E6(R3)のrisk-proportionate quality management、FDA risk-based monitoring、EMA RWD Data Quality Framework、CDISC ODM/SDTM/ADaM、FHIR/OMOP、21 CFR Part 11相当の監査可能性が関係する。したがって、モデル性能だけでなく、入力データlineage、schema version、audit trail、モデルversion、config hash、reviewer decisionを保存する必要がある。

## 仕様

### 入力

- CSV/JSON/JSONL
- 必須識別子: `study_id`, `site_id`, `subject_id`, `record_id`, `form_name`
- 時間列: `visit_date`, `recorded_at`, `query_opened_at`, `query_closed_at`
- 値列: `age`, `sbp`, `dbp`, `lab_value`, `dose` など
- 監査列: `user_id`, `role`, `change_reason`, `change_count`
- query/lock列: `is_query_open`, `query_count`, `freeze_flag`, `lock_flag`

### 出力

- `record_id`
- `score` 0から1
- `label`: `normal`, `warning`, `critical`
- `triggered_rules`
- `model_contributions`
- `explanation`

## 理論

異常は少なくとも次の5層に分ける。

| 層 | 定義 | 例 |
|---|---|---|
| 単変量外れ | 1変数の極端値 | 年齢負値、SBP 320 |
| 多変量異常 | 組み合わせとして不自然 | 年齢・用量・visitの不自然な組合せ |
| 論理矛盾 | 業務制約違反 | recorded_at < visit_date |
| 欠損パターン異常 | 欠損構造の偏り | 特定siteでendpoint欠損急増 |
| drift | 分布や生成過程の変化 | EDC移行後の値分布shift |

## 実務上の制約

- 教師なし異常検知は「珍しさ」を検出するだけで、医学的・規制上の重要性を直接推定しない。
- protocol amendment、EDC migration、site mix change は分布ドリフトと誤検知を生む。
- 深層学習は性能向上の余地があるが、validation、説明性、再学習監視、GPUコストが重い。

## 推測・仮説

初期データではラベル付き異常が乏しい可能性が高いため、query log、監査所見、ルールヒットをpseudo-labelとして蓄積し、後段で教師ありモデルに接続する設計が現実的である。

## 提案

1. PoCでは duplicate, required missing, temporal inconsistency, physiologic range, site-level drift に絞る。
2. reviewer feedback を保存し、top-k precisionを実務KPIにする。
3. 自動query発行ではなく、人間review queueの優先順位付けに限定する。
4. AutoEncoder/Transformerは、系列性が強いフォームまたはsite riskに限定して二段階目以降に追加する。

## 批判的立場

このSkillは、誤検知をゼロにできない。むしろ実務では、レビュー工数を増やすリスクがある。特にRWDは収集過程が不均一で、外れ値が医学的に妥当な場合も多い。初期導入ではモデルの複雑性よりも、schema contract、auditability、reviewer workflow、誤検知コストの管理を優先すべきである。
