class CampsiteSignupPricing
  Result = Data.define(
    :amount_cents,
    :currency,
    :adult_count,
    :counted_minor_count,
    :free_minor_count,
    :night_count,
    :extra_night_count,
    :adult_unit_amount_cents,
    :counted_minor_unit_amount_cents,
    :first_two_nights_fee_cents,
    :extra_night_fee_cents,
    :minor_fee_cents,
    :minor_extra_night_fee_cents,
    :uncounted_minor_age_limit,
    :line_items
  ) do
    def free?
      amount_cents.zero?
    end

    def snapshot
      {
        "currency" => currency,
        "amount_cents" => amount_cents,
        "adult_count" => adult_count,
        "counted_minor_count" => counted_minor_count,
        "free_minor_count" => free_minor_count,
        "night_count" => night_count,
        "extra_night_count" => extra_night_count,
        "adult_unit_amount_cents" => adult_unit_amount_cents,
        "counted_minor_unit_amount_cents" => counted_minor_unit_amount_cents,
        "first_two_nights_fee_cents" => first_two_nights_fee_cents,
        "extra_night_fee_cents" => extra_night_fee_cents,
        "minor_fee_cents" => minor_fee_cents,
        "minor_extra_night_fee_cents" => minor_extra_night_fee_cents,
        "uncounted_minor_age_limit" => uncounted_minor_age_limit,
        "line_items" => line_items
      }
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(arrival_date:, checkout_date:, adult_guest_count: 0, minor_ages: [], settings: SiteSetting.current)
    @arrival_date = arrival_date
    @checkout_date = checkout_date
    @adult_guest_count = adult_guest_count.to_i
    @minor_ages = minor_ages.map(&:to_i)
    @settings = settings
  end

  def call
    adult_count = 1 + @adult_guest_count
    counted_minor_count = @minor_ages.count { |age| age >= @settings.uncounted_minor_age_limit }
    free_minor_count = @minor_ages.size - counted_minor_count
    adult_unit_amount_cents = @settings.first_two_nights_fee_cents + (@settings.extra_night_fee_cents * extra_night_count)
    counted_minor_unit_amount_cents = @settings.minor_fee_cents + (@settings.minor_extra_night_fee_cents * extra_night_count)
    adult_total_cents = adult_count * adult_unit_amount_cents
    counted_minor_total_cents = counted_minor_count * counted_minor_unit_amount_cents
    amount_cents = adult_total_cents + counted_minor_total_cents

    Result.new(
      amount_cents: amount_cents,
      currency: "usd",
      adult_count: adult_count,
      counted_minor_count: counted_minor_count,
      free_minor_count: free_minor_count,
      night_count: night_count,
      extra_night_count: extra_night_count,
      adult_unit_amount_cents: adult_unit_amount_cents,
      counted_minor_unit_amount_cents: counted_minor_unit_amount_cents,
      first_two_nights_fee_cents: @settings.first_two_nights_fee_cents,
      extra_night_fee_cents: @settings.extra_night_fee_cents,
      minor_fee_cents: @settings.minor_fee_cents,
      minor_extra_night_fee_cents: @settings.minor_extra_night_fee_cents,
      uncounted_minor_age_limit: @settings.uncounted_minor_age_limit,
      line_items: line_items(adult_count, counted_minor_count, adult_unit_amount_cents, counted_minor_unit_amount_cents)
    )
  end

  private

  def night_count
    return 0 if @arrival_date.blank? || @checkout_date.blank?

    (@checkout_date.to_date - @arrival_date.to_date).to_i
  end

  def extra_night_count
    [ night_count - 2, 0 ].max
  end

  def line_items(adult_count, counted_minor_count, adult_unit_amount_cents, counted_minor_unit_amount_cents)
    items = []
    if adult_count.positive? && adult_unit_amount_cents.positive?
      items << {
        "description" => "Adult participant",
        "quantity" => adult_count,
        "unit_amount_cents" => adult_unit_amount_cents,
        "total_cents" => adult_count * adult_unit_amount_cents
      }
    end

    if counted_minor_count.positive? && counted_minor_unit_amount_cents.positive?
      items << {
        "description" => "Counted minor",
        "quantity" => counted_minor_count,
        "unit_amount_cents" => counted_minor_unit_amount_cents,
        "total_cents" => counted_minor_count * counted_minor_unit_amount_cents
      }
    end

    items
  end
end
