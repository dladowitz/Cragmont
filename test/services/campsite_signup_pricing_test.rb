require "test_helper"

class CampsiteSignupPricingTest < ActiveSupport::TestCase
  setup do
    @settings = SiteSetting.current
    @settings.update!(
      first_two_nights_fee: "40",
      extra_night_fee: "15",
      minor_fee: "20",
      minor_extra_night_fee: "5",
      uncounted_minor_age_limit: 13
    )
  end

  test "charges first two nights fee for one or two nights" do
    one_night = price(arrival_date: Date.new(2026, 6, 1), checkout_date: Date.new(2026, 6, 2))
    two_nights = price(arrival_date: Date.new(2026, 6, 1), checkout_date: Date.new(2026, 6, 3))

    assert_equal 4000, one_night.amount_cents
    assert_equal 4000, two_nights.amount_cents
  end

  test "charges extra night fee for nights after the first two" do
    result = price(arrival_date: Date.new(2026, 6, 1), checkout_date: Date.new(2026, 6, 5))

    assert_equal 7000, result.amount_cents
    assert_equal 2, result.extra_night_count
  end

  test "charges adult guests full price" do
    result = price(
      arrival_date: Date.new(2026, 6, 1),
      checkout_date: Date.new(2026, 6, 4),
      adult_guest_count: 2
    )

    assert_equal 3, result.adult_count
    assert_equal 16_500, result.amount_cents
  end

  test "uncounted minors are free and counted minors use configured minor fees" do
    @settings.update!(first_two_nights_fee: "40.01", extra_night_fee: "0", minor_fee: "20.01", minor_extra_night_fee: "0")

    result = price(
      arrival_date: Date.new(2026, 6, 1),
      checkout_date: Date.new(2026, 6, 3),
      minor_ages: [ 12, 13 ]
    )

    assert_equal 1, result.free_minor_count
    assert_equal 1, result.counted_minor_count
    assert_equal 2001, result.counted_minor_unit_amount_cents
    assert_equal 6002, result.amount_cents
  end

  test "counted minors use configured extra night fee after the first two nights" do
    result = price(
      arrival_date: Date.new(2026, 6, 1),
      checkout_date: Date.new(2026, 6, 5),
      minor_ages: [ 13 ]
    )

    assert_equal 2, result.extra_night_count
    assert_equal 3000, result.counted_minor_unit_amount_cents
    assert_equal 10_000, result.amount_cents
  end

  test "snapshot preserves the pricing inputs" do
    result = price(
      arrival_date: Date.new(2026, 6, 1),
      checkout_date: Date.new(2026, 6, 5),
      adult_guest_count: 1,
      minor_ages: [ 14 ]
    )

    assert_equal 17_000, result.amount_cents
    assert_equal 2, result.snapshot["adult_count"]
    assert_equal 1, result.snapshot["counted_minor_count"]
    assert_equal 2, result.snapshot["extra_night_count"]
    assert_equal 4000, result.snapshot["first_two_nights_fee_cents"]
    assert_equal 500, result.snapshot["minor_extra_night_fee_cents"]
  end

  private

  def price(**attributes)
    CampsiteSignupPricing.call(settings: @settings, **attributes)
  end
end
