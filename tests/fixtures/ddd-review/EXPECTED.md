# ddd-review フィクスチャ — 期待される指摘

`/ddd-review tests/fixtures/ddd-review/` を実行し、この一覧と突き合わせる。
場所は行番号ではなく型・関数名で照合する。重要度は ±1 段階のズレを許容する。
検査軸8（境界づけられたコンテキスト）はこのフィクスチャでは演習していない。

## 検出すべき指摘（7件 — 関連する指摘の統合報告は可）

| # | 観点 | 場所 | 期待される内容 | 重要度目安 |
|---|------|------|----------------|-----------|
| 1 | 貧血モデル | `order.go` `Order` + `order_service.go` `CancelOrder` / `CancelAllForCustomer` | 状態遷移が setter 任せで、キャンセル可否判定がサービス層2箇所に重複。片方だけ直すと不正遷移が入る | High〜Medium |
| 2 | 集約迂回 | `order_service.go` `AddItem` | 明細の直接 append + 合計の外部再計算。件数上限などの不変条件チェックをどこも通らない。`GetItems` が内部スライスをそのまま返す点も可 | High |
| 3 | リポジトリ | `order_service.go` `OrderItemRepository` | 集約ルートでない明細専用リポジトリ。ルート経由の不変条件を迂回する裏口 | High |
| 4 | リポジトリ | `order_service.go` `OrderRepository.UpdateOrderStatus` | 集約の一部だけの部分更新。不変条件の破れた状態で保存できる | High〜Medium |
| 5 | ドメイン層の純粋性 | `order.go` `Order` | gorm タグ付きで永続化モデルと兼用。DB スキーマの都合がドメインモデルを引きずる | Medium |
| 6 | 値オブジェクト | `order.go` `AddAmounts` + `order_service.go` `RegisterCustomerEmail` / `UpdateCustomerEmail` | 通貨違いの加算が型で防げない。メール検証が2箇所にコピペ | Medium |
| 7 | サービスの責務配置 / ユビキタス言語 | `order_service.go` `Checkout`、`order.go` `Order.IsEstimate` | 割引率という業務ルールが usecase にベタ書き。見積もりと注文がフラグで1つの型に同居 | Medium〜Low |

## 指摘してはいけないもの（過剰指摘の検査）

- `order.go` `OrderResponse` — DTO。貧血で正しい
- `order_service.go` `OrderQueryService` — 読み取り専用で複数集約をまたぐクエリ。CQRS 的に正しい
- 実害シナリオの書けない「DDD 的にはこうすべき」だけの指摘

## 合格基準

- 検出: 上記1〜4（不変条件が実際に破れる経路）がすべて指摘される。5〜7 は少なくとも2つ
- 過剰指摘: 上記2箇所への指摘が出ない
- 形式: 各指摘に実害シナリオ（「◯◯の操作/変更が来たとき△△が破れる」）が付いている
