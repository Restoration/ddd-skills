// qa-engineer 評価用フィクスチャ — テスト漏れを意図的に仕込んだテストコード。
// 欠落・問題は意図的 — 直さないこと。EXPECTED.md に期待される指摘一覧がある。
package fixtures

import (
	"testing"
	"time"
)

func newActiveCoupon(t *testing.T, percent int) *Coupon {
	t.Helper()
	c, err := NewCoupon("TEST", percent, 1000, time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC), 10)
	if err != nil {
		t.Fatalf("failed to create coupon: %v", err)
	}
	return c
}

// [同値クラスの重複] 10/20/30% は全部同じ同値クラス。
// 境界（1, 100）や不正値（0, 101）のテストはどこにもない。
func TestApply_TenPercent(t *testing.T) {
	c := newActiveCoupon(t, 10)
	got, err := c.Apply(10000, time.Date(2029, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	if got != 9000 {
		t.Errorf("got %d, want 9000", got)
	}
}

func TestApply_TwentyPercent(t *testing.T) {
	c := newActiveCoupon(t, 20)
	got, err := c.Apply(10000, time.Date(2029, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	if got != 8000 {
		t.Errorf("got %d, want 8000", got)
	}
}

func TestApply_ThirtyPercent(t *testing.T) {
	c := newActiveCoupon(t, 30)
	got, err := c.Apply(10000, time.Date(2029, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	if got != 7000 {
		t.Errorf("got %d, want 7000", got)
	}
}

// [検出力のないテスト] err しか見ておらず、割引後の金額を検証していない。
// 計算式が壊れてもこのテストは通る。
func TestApply_Succeeds(t *testing.T) {
	c := newActiveCoupon(t, 50)
	_, err := c.Apply(10000, time.Date(2029, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Errorf("expected success, got %v", err)
	}
}

// [実装ロジックの複製] 期待値を実装と同じ式で計算している。
// 実装の式にバグが入れば、期待値にも同じバグが複製されて通ってしまう。
func TestApply_FortyPercent(t *testing.T) {
	c := newActiveCoupon(t, 40)
	amount := int64(9999)
	got, err := c.Apply(amount, time.Date(2029, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	want := amount - amount*int64(c.Percent)/100
	if got != want {
		t.Errorf("got %d, want %d", got, want)
	}
}

// [flaky シグナル] time.Now() 依存。ExpiresAt との差がわずかで、
// 実行タイミング次第で結果が変わりうる。期限「ちょうど」の境界も検証できていない。
func TestApply_NotExpired(t *testing.T) {
	c, err := NewCoupon("TEST", 10, 1000, time.Now().Add(50*time.Millisecond), 10)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := c.Apply(10000, time.Now()); err != nil {
		t.Errorf("expected success, got %v", err)
	}
}

// [状態遷移: 正常パスのみ] active → paused → active の往復だけ。
// 不正遷移（revoked からの Resume、paused の Pause 等）の拒否テストがない。
func TestPauseAndResume(t *testing.T) {
	c := newActiveCoupon(t, 10)
	if err := c.Pause(); err != nil {
		t.Fatal(err)
	}
	if c.Status != "paused" {
		t.Errorf("got %s, want paused", c.Status)
	}
	if err := c.Resume(); err != nil {
		t.Fatal(err)
	}
	if c.Status != "active" {
		t.Errorf("got %s, want active", c.Status)
	}
}
