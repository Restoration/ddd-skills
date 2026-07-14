// ddd-review 評価用フィクスチャ — ドメイン層のつもりのコード。
// EXPECTED.md に期待される指摘一覧がある。違反は意図的 — 直さないこと。
package fixtures

// ---------------------------------------------------------------------------
// [貧血モデル + 純粋性違反 + 語彙の同居]
// Order: 全フィールド public + setter のみで、業務ルール（状態遷移の可否、
// 合計の整合）を何も守っていない。ドメインモデルのつもりで gorm タグ付き
// = 永続化モデルと兼用。さらに「見積もり」と「注文」が IsEstimate フラグで
// 1つの型に同居している。
// ---------------------------------------------------------------------------

type Order struct {
	ID         string       `gorm:"primaryKey"`
	CustomerID string       `gorm:"index"`
	Status     string       `gorm:"index"` // "draft" / "paid" / "shipped" / "cancelled"
	Items      []*OrderItem `gorm:"foreignKey:OrderID"`
	Total      float64
	Currency   string
	IsEstimate bool // true なら見積もり。注文と同じ型・同じテーブルを共用
}

func (o *Order) SetStatus(s string) { o.Status = s }

func (o *Order) GetItems() []*OrderItem { return o.Items }

type OrderItem struct {
	ID        string `gorm:"primaryKey"`
	OrderID   string `gorm:"index"`
	SKU       string
	Quantity  int
	UnitPrice float64
}

// ---------------------------------------------------------------------------
// [値オブジェクト不在] 金額が float64 + currency string のペアで引き回され、
// 通貨不一致の加算を型で防げない。
// ---------------------------------------------------------------------------

func AddAmounts(a float64, aCur string, b float64, bCur string) float64 {
	// 通貨が違っても呼べてしまう
	return a + b
}

// ---------------------------------------------------------------------------
// [指摘しないこと] レスポンス DTO。データ運搬役であり、貧血で正しい。
// ---------------------------------------------------------------------------

type OrderResponse struct {
	ID     string  `json:"id"`
	Status string  `json:"status"`
	Total  float64 `json:"total"`
}
