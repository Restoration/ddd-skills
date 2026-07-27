# qa-engineer フィクスチャ — 期待される指摘

`/qa-engineer tests/fixtures/qa-engineer/` を実行し（REVIEW モードに入るはず）、この一覧と突き合わせる。
場所は行番号ではなく関数名で照合する。重要度は ±1 段階のズレを許容する。
実装（`coupon.go`）は概ね健全に書いてあり、レビューの主対象はテスト（`coupon_test.go`）の検出漏れ。

## 検出すべき指摘（6件 — 関連する指摘の統合報告は可）

| # | 検査軸 | 場所 | 期待される内容 | 重要度目安 |
|---|--------|------|----------------|-----------|
| 1 | B. 異常系未カバー | `coupon_test.go` 全体 vs `Apply` / `NewCoupon` | `ErrNotActive` / `ErrExpired` / `ErrBelowMinimum` / `ErrUsageLimitReached` および `NewCoupon` のバリデーションエラーを踏むテストがゼロ。エラー処理が一度も実行されていない | High |
| 2 | A. 境界値未カバー | `coupon_test.go` 全体 vs `Percent` / `MinOrderAmount` / `UsageLimit` / `ExpiresAt` | Percent 1/100（と不正値 0/101）、MinOrderAmount ちょうど/未満、UsageLimit 到達、ExpiresAt 同時刻ちょうど（仕様上「有効」）の境界テストがない | High〜Medium |
| 3 | C. 状態遷移未カバー | `TestPauseAndResume` | 正常な往復のみで、不正遷移の拒否（revoked からの `Resume`、paused への再 `Pause`、revoked クーポンの `Apply` 拒否）のテストがない | High〜Medium |
| 4 | D. 検出力のないテスト | `TestApply_Succeeds` / `TestApply_FortyPercent` | 前者は err のみで金額を未検証、後者は期待値を実装と同じ式で計算しており、計算式のバグが両方素通りする | Medium |
| 5 | F. flaky シグナル | `TestApply_NotExpired` | `time.Now()` と 50ms 差の ExpiresAt に依存し、実行タイミングで結果が変わりうる。固定時刻を渡す形にすべき | Medium〜Low |
| 6 | E. 同値クラスの重複 | `TestApply_TenPercent` / `TwentyPercent` / `ThirtyPercent` | 同じ同値クラスを値だけ変えて3回テストして件数を稼ぎ、境界・異常系（#1, #2）が欠けている | Low |

## 指摘してはいけないもの（過剰指摘の検査）

- `coupon.go` の実装への設計指摘（DDD・アーキテクチャの観点はこのスキルのスコープ外。実装は概ね健全）
- `Code` フィールド等、検証も分岐もない値へのテスト要求
- 「カバレッジを上げるため」だけのテスト追加要求（すべての指摘に「通ってしまうバグ」の具体例が必要）

## 合格基準

- 検出: 上記 1〜3（バグが素通りする経路）がすべて指摘される。4〜6 は少なくとも2つ
- 過剰指摘: 上記3項目への指摘が出ない
- 形式: 各指摘に「実装に◯◯というバグが入っても、このテストは通る」の形の実害説明が付いている
