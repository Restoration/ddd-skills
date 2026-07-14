// ddd-review 評価用フィクスチャ — サービス層のつもりのコード。
// EXPECTED.md に期待される指摘一覧がある。違反は意図的 — 直さないこと。
package fixtures

import (
	"fmt"
	"regexp"
	"strings"
)

// ---------------------------------------------------------------------------
// [リポジトリ違反]
// - OrderItemRepository: 集約ルートでない明細専用のリポジトリ。集約ルート
//   経由の不変条件チェック（明細は10件まで・合計 = 明細の和）を迂回する裏口
// - UpdateOrderStatus: 集約の一部だけを保存する部分更新
// ---------------------------------------------------------------------------

type OrderRepository interface {
	Find(id string) (*Order, error)
	Save(o *Order) error
	UpdateOrderStatus(id string, status string) error
}

type OrderItemRepository interface {
	Save(item *OrderItem) error
	DeleteByOrderID(orderID string) error
}

// ---------------------------------------------------------------------------
// [貧血モデルの帰結] キャンセル可否の判定がサービス層の2箇所に重複。
// エンティティにメソッドがないため、呼び出し側が毎回同じ判定を組み立てる。
// 片方だけ条件を直すと不正遷移が入る。
// ---------------------------------------------------------------------------

type OrderService struct {
	orders OrderRepository
	items  OrderItemRepository
}

func (s *OrderService) CancelOrder(id string) error {
	o, err := s.orders.Find(id)
	if err != nil {
		return err
	}
	if o.Status == "shipped" || o.Status == "cancelled" {
		return fmt.Errorf("キャンセル不可")
	}
	o.SetStatus("cancelled")
	return s.orders.UpdateOrderStatus(id, "cancelled")
}

func (s *OrderService) CancelAllForCustomer(customerID string, orders []*Order) error {
	for _, o := range orders {
		if o.Status == "shipped" || o.Status == "cancelled" {
			continue // 同じ判定の重複
		}
		o.SetStatus("cancelled")
		if err := s.orders.UpdateOrderStatus(o.ID, "cancelled"); err != nil {
			return err
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// [集約迂回] 明細をルートの Order を通さず直接追加・書き換えし、合計も外から
// 再計算して書き戻している（Tell, Don't Ask 違反）。「明細は10件まで」の
// チェックはどこにもなく、OrderItemRepository 経由なら合計も狂う。
// ---------------------------------------------------------------------------

func (s *OrderService) AddItem(o *Order, item *OrderItem) error {
	o.Items = append(o.Items, item) // ルートのメソッドを経由しない直接変更
	total := 0.0
	for _, it := range o.Items {
		total += it.UnitPrice * float64(it.Quantity)
	}
	o.Total = total
	return s.items.Save(item) // 集約の一部だけを単独保存
}

// ---------------------------------------------------------------------------
// [サービスの責務配置] 割引率という業務ルールの本体が usecase 関数にベタ書き。
// 別ユースケース（見積もり作成）が同じルールを必要とした時点でコピペされる。
// ---------------------------------------------------------------------------

func (s *OrderService) Checkout(o *Order, memberRank string) error {
	discount := 0.0
	if memberRank == "gold" && o.Total >= 10000 {
		discount = 0.10
	} else if memberRank == "silver" && o.Total >= 30000 {
		discount = 0.05
	}
	o.Total = o.Total * (1 - discount)
	o.SetStatus("paid")
	return s.orders.Save(o)
}

// ---------------------------------------------------------------------------
// [値オブジェクト不在] メール形式チェックが2箇所にコピペ。値オブジェクト
// （コンストラクタで検証）なら1箇所で済み、未検証の文字列が流れない。
// ---------------------------------------------------------------------------

var emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+$`)

func (s *OrderService) RegisterCustomerEmail(email string) error {
	if !emailRe.MatchString(strings.TrimSpace(email)) {
		return fmt.Errorf("invalid email")
	}
	return nil
}

func (s *OrderService) UpdateCustomerEmail(email string) error {
	if !emailRe.MatchString(strings.TrimSpace(email)) {
		return fmt.Errorf("invalid email")
	}
	return nil
}

// ---------------------------------------------------------------------------
// [指摘しないこと] 検索画面用の読み取り専用クエリ。複数集約をまたぐが更新
// しないので、集約境界の違反として指摘してはいけない。
// ---------------------------------------------------------------------------

type OrderSearchRow struct {
	OrderID      string
	CustomerName string
	Total        float64
}

type OrderQueryService interface {
	SearchWithCustomer(keyword string) ([]OrderSearchRow, error)
}
