class SiteSetting < ApplicationRecord
  validates :uncounted_minor_age_limit,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 17 }
  validates :first_two_nights_fee_cents, :extra_night_fee_cents, :minor_fee_cents, :minor_extra_night_fee_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.current
    first_or_create!
  end

  def first_two_nights_fee
    cents_to_decimal(first_two_nights_fee_cents)
  end

  def first_two_nights_fee=(value)
    self.first_two_nights_fee_cents = dollars_to_cents(value)
  end

  def extra_night_fee
    cents_to_decimal(extra_night_fee_cents)
  end

  def extra_night_fee=(value)
    self.extra_night_fee_cents = dollars_to_cents(value)
  end

  def minor_fee
    cents_to_decimal(minor_fee_cents)
  end

  def minor_fee=(value)
    self.minor_fee_cents = dollars_to_cents(value)
  end

  def minor_extra_night_fee
    cents_to_decimal(minor_extra_night_fee_cents)
  end

  def minor_extra_night_fee=(value)
    self.minor_extra_night_fee_cents = dollars_to_cents(value)
  end

  private

  def cents_to_decimal(cents)
    BigDecimal(cents.to_s) / 100
  end

  def dollars_to_cents(value)
    (BigDecimal(value.to_s.presence || "0") * 100).round
  end
end
