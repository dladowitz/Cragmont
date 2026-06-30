class DayTripSignup < ApplicationRecord
  STATUSES = %w[confirmed waitlisted canceled].freeze
  CLIMBING_ABILITIES = %w[top_rope lead bouldering none].freeze
  CLIMBING_ABILITY_LABELS = {
    "top_rope" => "Top rope",
    "lead" => "Lead",
    "bouldering" => "Bouldering",
    "none" => "None"
  }.freeze
  SKILL_LEVELS = CLIMBING_ABILITIES
  SKILL_LEVEL_LABELS = CLIMBING_ABILITY_LABELS
  MAX_GUESTS_PER_SIGNUP = 1
  MAX_MINORS_PER_SIGNUP = 1

  belongs_to :trip
  belongs_to :user
  belongs_to :guest_of_day_trip_signup,
    class_name: "DayTripSignup",
    optional: true,
    inverse_of: :guest_signups
  has_many :guest_signups,
    -> { order(:guest_position, :created_at) },
    class_name: "DayTripSignup",
    foreign_key: :guest_of_day_trip_signup_id,
    dependent: :destroy,
    inverse_of: :guest_of_day_trip_signup
  has_many :day_trip_signup_minors, dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "confirmed"
  scope :active, -> { where.not(status: "canceled") }
  scope :primary, -> { where(guest_of_day_trip_signup_id: nil) }
  scope :guests, -> { where.not(guest_of_day_trip_signup_id: nil) }

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :climbing_abilities_are_known
  validate :climbing_abilities_are_present
  validates :user_id,
    uniqueness: {
      scope: :trip_id,
      conditions: -> { active },
      message: "is already signed up for this trip"
    },
    unless: :canceled?
  validates :guest_position, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates_associated :day_trip_signup_minors
  validate :trip_is_day_trip
  validate :guest_link_is_valid
  validate :party_limit

  def guest?
    guest_of_day_trip_signup_id.present?
  end

  def primary_signup
    guest_of_day_trip_signup || self
  end

  def includes_guests?
    guest_signups.any?
  end

  def includes_minors?
    day_trip_signup_minors.any?
  end

  def party_capacity_count
    return 1 if guest?

    1 + guest_signups.size + day_trip_signup_minors.size
  end

  def lead_count
    climbing_ability_enabled?("lead") ? 1 : 0
  end

  def top_rope_count
    (climbing_ability_enabled?("top_rope") ? 1 : 0) + (guest? ? 0 : day_trip_signup_minors.size)
  end

  def public_participant_name
    return user.public_name unless includes_minors?

    "#{user.public_name} + #{day_trip_signup_minors.size} #{'minor'.pluralize(day_trip_signup_minors.size)}"
  end

  def skill_level_label
    climbing_ability_labels.to_sentence
  end

  def climbing_abilities
    raw_abilities = self[:climbing_abilities]
    values = if raw_abilities.present?
      JSON.parse(raw_abilities)
    else
      []
    end
    normalize_climbing_ability_values(values)
  rescue JSON::ParserError, TypeError
    normalize_climbing_ability_values(raw_abilities)
  end

  def climbing_abilities=(values)
    self[:climbing_abilities] = normalize_climbing_ability_values(values).to_json
  end

  def climbing_ability_enabled?(ability)
    climbing_abilities.include?(ability.to_s)
  end

  def climbing_ability_labels
    climbing_abilities.filter_map { |ability| CLIMBING_ABILITY_LABELS[ability] }
  end

  def shared_gear_summary
    items = []
    items << "Rope (60m)" if rope_60m?
    items << "Rope (70m)" if rope_70m?
    items << "Quickdraws and sport anchor" if quickdraws_and_sport_anchor?
    items << "Clip stick" if clip_stick?
    items << "Cams and trad anchor" if cams_nuts_and_trad_anchor?
    items << "Crash pad#{"s" if crash_pad_count != 1} (#{crash_pad_count})" if crash_pad_count.positive?
    items.presence&.join(", ") || "None"
  end

  def waiver_signed?
    return true if !includes_minors? && user.current_waiver_for_year(trip.start_date.year).present?

    waiver_signed_at.present?
  end

  private

  def normalize_climbing_ability_values(values)
    Array(values).flatten.map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def climbing_abilities_are_known
    unknown_abilities = climbing_abilities - CLIMBING_ABILITIES
    return if unknown_abilities.empty?

    errors.add(:climbing_abilities, "include unknown climbing abilities")
  end

  def climbing_abilities_are_present
    errors.add(:climbing_abilities, "can't be blank") if climbing_abilities.empty?
  end

  def trip_is_day_trip
    return if trip&.day_trip?

    errors.add(:trip, "must be a day trip")
  end

  def guest_link_is_valid
    return if guest_of_day_trip_signup.blank?

    if guest_of_day_trip_signup == self
      errors.add(:guest_of_day_trip_signup, "cannot be the same signup")
    elsif guest_of_day_trip_signup.guest?
      errors.add(:guest_of_day_trip_signup, "must be a primary participant signup")
    end

    return if trip.blank? || guest_of_day_trip_signup.trip_id.blank? || trip_id == guest_of_day_trip_signup.trip_id

    errors.add(:guest_of_day_trip_signup, "must belong to the same trip")
  end

  def party_limit
    return if guest?

    if guest_signups.size > MAX_GUESTS_PER_SIGNUP
      errors.add(:guest_signups, "cannot include more than #{MAX_GUESTS_PER_SIGNUP} additional adult")
    end

    if day_trip_signup_minors.size > MAX_MINORS_PER_SIGNUP
      errors.add(:day_trip_signup_minors, "cannot include more than #{MAX_MINORS_PER_SIGNUP} minor")
    end

    errors.add(:base, "Choose either one additional adult or one minor") if guest_signups.any? && day_trip_signup_minors.any?
  end
end
