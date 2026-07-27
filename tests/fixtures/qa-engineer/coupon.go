// qa-engineer 評価用フィクスチャ — レビュー対象の実装。
// この実装自体は概ね健全に書いてある（レビューの主対象は coupon_test.go のテスト漏れ）。
// EXPECTED.md に期待される指摘一覧がある。
package fixtures

import (
	"errors"
	"time"
)

var (
	ErrNotActive         = errors.New("coupon is not active")
	ErrExpired           = errors.New("coupon is expired")
	ErrBelowMinimum      = errors.New("order amount is below minimum")
	ErrUsageLimitReached = errors.New("usage limit reached")
)

// Coupon は割引クーポン。
// 不変条件: Percent は 1〜100 / UsageLimit は 1 以上 / usedCount は UsageLimit を超えない。
// 状態遷移: active ⇄ paused、任意の状態 → revoked（revoked から復帰は不可）。
type Coupon struct {
	Code           string
	Percent        int       // 割引率。1〜100
	MinOrderAmount int64     // この金額以上の注文にのみ適用できる
	ExpiresAt      time.Time // この時刻まで有効（同時刻ちょうどは有効）
	UsageLimit     int       // 利用可能回数
	usedCount      int
	Status         string // "active" / "paused" / "revoked"
}

func NewCoupon(code string, percent int, minOrderAmount int64, expiresAt time.Time, usageLimit int) (*Coupon, error) {
	if percent < 1 || percent > 100 {
		return nil, errors.New("percent must be between 1 and 100")
	}
	if usageLimit < 1 {
		return nil, errors.New("usage limit must be at least 1")
	}
	return &Coupon{
		Code:           code,
		Percent:        percent,
		MinOrderAmount: minOrderAmount,
		ExpiresAt:      expiresAt,
		UsageLimit:     usageLimit,
		Status:         "active",
	}, nil
}

// Pause は active なクーポンを一時停止する。
func (c *Coupon) Pause() error {
	if c.Status != "active" {
		return errors.New("only active coupon can be paused")
	}
	c.Status = "paused"
	return nil
}

// Resume は paused なクーポンを再開する。revoked からは再開できない。
func (c *Coupon) Resume() error {
	if c.Status != "paused" {
		return errors.New("only paused coupon can be resumed")
	}
	c.Status = "active"
	return nil
}

// Revoke はクーポンを失効させる。以後どの操作もできない。
func (c *Coupon) Revoke() {
	c.Status = "revoked"
}

// Apply は注文金額に割引を適用した金額を返し、利用回数を1消費する。
func (c *Coupon) Apply(orderAmount int64, now time.Time) (int64, error) {
	if c.Status != "active" {
		return 0, ErrNotActive
	}
	if now.After(c.ExpiresAt) {
		return 0, ErrExpired
	}
	if orderAmount < c.MinOrderAmount {
		return 0, ErrBelowMinimum
	}
	if c.usedCount >= c.UsageLimit {
		return 0, ErrUsageLimitReached
	}
	c.usedCount++
	return orderAmount - orderAmount*int64(c.Percent)/100, nil
}
