module ApplicationHelper
  def required_marker
    safe_join([
      tag.span("*", class: "required-marker", aria: { hidden: "true" }),
      tag.span("required", class: "visually-hidden")
    ], " ")
  end

  def required_label(form, method, text = nil, options = {})
    form.label(method, nil, options) do
      safe_join([ text || method.to_s.humanize, required_marker ], " ")
    end
  end

  def required_label_tag(name, text = nil, options = {})
    label_tag(name, nil, options) do
      safe_join([ text || name.to_s.humanize, required_marker ], " ")
    end
  end

  def visible_environment_name
    return unless Rails.env.development? || Rails.env.staging?

    Rails.env.to_s.titleize
  end

  def help_request_status_class(status)
    case status
    when "replied"
      "replied-status"
    when "resolved"
      "resolved-status"
    else
      "open-status"
    end
  end

  def help_request_status_pill(help_request)
    tag.span(
      help_request.status.titleize,
      class: [ "status-pill", help_request_status_class(help_request.status) ]
    )
  end

  def format_cents(cents)
    number_to_currency(BigDecimal(cents.to_i.to_s) / 100)
  end

  def stripe_dashboard_payment_url(payment_intent_id)
    return if payment_intent_id.blank? || ENV["STRIPE_ACCOUNT_ID"].blank?

    account_path = ENV.fetch("STRIPE_ACCOUNT_ID")
    environment_path = Rails.env.production? ? nil : "test"

    [ "https://dashboard.stripe.com", account_path, environment_path, "payments", payment_intent_id ].compact.join("/")
  end

  def payment_fee_breakdown(payment)
    PaymentFeeBreakdown.new(payment).line_items
  end

  def payment_fee_table_rows(payment)
    PaymentFeeBreakdown.new(payment).table_rows
  end

  def show_letter_opener_link?
    Rails.env.development? || (ENV["LETTER_OPENER_WEB"].present? && current_user&.super_admin?)
  end

  def letter_opener_path
    "/admin/letter_opener"
  end

  def letter_opener_label
    count = letter_opener_message_count

    count.nil? ? "Letter Opener" : "Letter Opener (#{count})"
  end

  def letter_opener_message_count
    return unless show_letter_opener_link?

    letters_location = letter_opener_letters_location
    return 0 unless letters_location.directory?

    Dir.children(letters_location).count do |entry|
      letters_location.join(entry).directory?
    end
  rescue SystemCallError
    nil
  end

  def letter_opener_letters_location
    if defined?(LetterOpenerWeb) && LetterOpenerWeb.respond_to?(:config)
      LetterOpenerWeb.config.letters_location
    else
      Rails.root.join("tmp", "letter_opener")
    end
  end

  class PaymentFeeBreakdown
    def initialize(payment)
      @payment = payment
      @signup = payment.campsite_signup
      @snapshot = payment.pricing_snapshot.presence || {}
    end

    def line_items
      adult_line_items + minor_line_items
    end

    def table_rows
      line_items.map do |line_item|
        first_two_nights = line_item[:details].find { |detail| detail[:label] == "First 2 nights" }
        additional_nights = line_item[:details].find { |detail| detail[:label].start_with?("Additional ") }
        total_cents = line_item[:details].sum { |detail| detail.fetch(:amount_cents, 0).to_i }

        {
          label: line_item[:label],
          first_two_nights: amount_text(first_two_nights),
          additional_nights: amount_text(additional_nights),
          total_cents: total_cents
        }
      end
    end

    private

    attr_reader :payment, :signup, :snapshot

    def adult_line_items
      (0...adult_count).map do |index|
        {
          label: adult_label(index),
          details: priced_details(first_two_nights_fee_cents, extra_night_fee_cents)
        }
      end
    end

    def minor_line_items
      minor_ages.each_with_index.map do |age, index|
        {
          label: minor_label(index, age),
          details: age < uncounted_minor_age_limit ? free_minor_details : priced_details(minor_fee_cents, minor_extra_night_fee_cents)
        }
      end
    end

    def adult_label(index)
      return signup.user.full_name if index.zero?

      adult_guests[index - 1]&.user&.full_name || "Adult #{index + 1}"
    end

    def minor_label(index, age)
      minor = minors[index]
      return "#{minor.first_name} #{minor.last_name}".strip if minor.present?

      "Minor #{index + 1} (age #{age})"
    end

    def adult_guests
      @adult_guests ||= signup.guest_signups.includes(:user).order(:guest_position, :created_at).to_a
    end

    def minors
      @minors ||= signup.campsite_signup_minors.order(:id).to_a
    end

    def priced_details(first_two_nights_cents, extra_night_cents)
      details = [ { label: "First 2 nights", amount_cents: first_two_nights_cents } ]
      if extra_night_count.positive?
        details << {
          label: additional_night_label(extra_night_count, extra_night_cents),
          amount_cents: extra_night_count * extra_night_cents
        }
      end
      details
    end

    def free_minor_details
      details = [ { label: "First 2 nights", amount_text: "Free" } ]
      if extra_night_count.positive?
        details << { label: additional_night_label(extra_night_count, 0), amount_text: "Free" }
      end
      details
    end

    def additional_night_label(count, fee_cents)
      "Additional #{'night'.pluralize(count)} (#{count} x #{ApplicationController.helpers.format_cents(fee_cents)})"
    end

    def amount_text(detail)
      return "None" if detail.blank?

      detail[:amount_text] || ApplicationController.helpers.format_cents(detail[:amount_cents])
    end

    def adult_count
      snapshot.fetch("adult_count", 1 + signup.guest_signups.size).to_i
    end

    def minor_ages
      ages = minors.map { |minor| minor.age.to_i }
      expected_count = snapshot.fetch("counted_minor_count", 0).to_i + snapshot.fetch("free_minor_count", 0).to_i

      return ages if expected_count.zero? || ages.size >= expected_count

      ages + Array.new(expected_count - ages.size, uncounted_minor_age_limit)
    end

    def extra_night_count
      snapshot.fetch("extra_night_count") { [ night_count - 2, 0 ].max }.to_i
    end

    def night_count
      snapshot.fetch("night_count", signup.night_count).to_i
    end

    def first_two_nights_fee_cents
      snapshot.fetch("first_two_nights_fee_cents", SiteSetting.current.first_two_nights_fee_cents).to_i
    end

    def extra_night_fee_cents
      snapshot.fetch("extra_night_fee_cents", SiteSetting.current.extra_night_fee_cents).to_i
    end

    def minor_fee_cents
      snapshot.fetch("minor_fee_cents", SiteSetting.current.minor_fee_cents).to_i
    end

    def minor_extra_night_fee_cents
      snapshot.fetch("minor_extra_night_fee_cents", SiteSetting.current.minor_extra_night_fee_cents).to_i
    end

    def uncounted_minor_age_limit
      snapshot.fetch("uncounted_minor_age_limit", SiteSetting.current.uncounted_minor_age_limit).to_i
    end
  end
end
