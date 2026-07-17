class Trip < ApplicationRecord
  STATUSES = %w[draft published archived].freeze
  TRIP_TYPES = %w[camping day_trip class_trip].freeze
  TRIP_TYPE_LABELS = {
    "camping" => "Camping Trip",
    "day_trip" => "Day Trip",
    "class_trip" => "Class"
  }.freeze
  CLIMBING_TYPES = %w[sport trad bouldering].freeze
  CLIMBING_TYPE_LABELS = {
    "sport" => "Sport",
    "trad" => "Trad",
    "bouldering" => "Bouldering"
  }.freeze
  DEFAULT_LATE_ARRIVAL_INSTRUCTIONS = "If you are running late here is the general area we'll be climbing at ...".freeze
  GROUP_FIRE_NIGHT_NONE = "none".freeze
  GROUP_FIRE_NIGHT_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  GROUP_FIRE_NIGHTS = ([ GROUP_FIRE_NIGHT_NONE ] + GROUP_FIRE_NIGHT_DAYS).freeze
  ALMOST_FULL_CAPACITY_THRESHOLD = 0.75

  belongs_to :campsite_coordinator,
    class_name: "User",
    optional: true,
    inverse_of: :coordinated_trips
  belongs_to :group_campfire_campsite,
    class_name: "Campsite",
    optional: true,
    inverse_of: :group_campfire_trip
  belongs_to :partner_company, optional: true
  has_many :campsites, dependent: :destroy
  has_many :campsite_signups, dependent: :destroy
  has_many :participants, through: :campsite_signups, source: :user
  has_many :day_trip_signups, dependent: :destroy
  has_many :day_trip_participants, through: :day_trip_signups, source: :user
  has_many :class_signups, dependent: :destroy
  has_many :class_participants, through: :class_signups, source: :user
  has_many :trip_payment_requests, dependent: :destroy
  has_many :trip_readiness_completions, dependent: :destroy
  has_one :trip_details_email, dependent: :destroy
  has_one_attached :day_trip_image

  before_validation :normalize_climbing_types
  before_validation :sync_single_day_end_date
  before_destroy :ensure_no_active_signups, prepend: true

  enum :status, STATUSES.index_with(&:itself), default: "draft"
  enum :trip_type, TRIP_TYPES.index_with(&:itself), default: "camping"

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :published_for_public, -> { active.published.order(start_date: :asc, name: :asc) }
  scope :archived_for_public, -> { active.archived.order(start_date: :desc, name: :asc) }
  scope :visible_for_public, -> { active.where(status: %w[published archived]) }

  validates :name, :location, :start_date, :end_date, :status, :trip_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :trip_type, inclusion: { in: TRIP_TYPES }
  validates :cost_cents, :participant_capacity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :group_fire_night, inclusion: { in: GROUP_FIRE_NIGHTS }, allow_blank: true
  validates :meeting_time, :meeting_location, :meeting_location_url, :late_arrival_instructions, presence: true, if: :day_trip?
  validates :partner_company, :class_signup_url, :class_original_price, :weather_url, presence: true, if: :class_trip?
  validate :single_day_dates_match
  validate :climbing_types_are_known
  validate :day_trip_climbing_types_present
  validate :class_capacity_present
  validate :end_date_after_start_date
  validate :group_campfire_campsite_belongs_to_trip

  def campsite_count
    return 0 if day_trip? || class_trip?

    campsites.size
  end

  def total_participant_capacity
    return participant_capacity if day_trip? || class_trip?

    campsites.loaded? ? campsites.sum(&:participant_capacity) : campsites.sum(:participant_capacity)
  end

  def total_car_capacity
    campsites.loaded? ? campsites.sum(&:car_capacity) : campsites.sum(:car_capacity)
  end

  def confirmed_signup_count
    confirmed_capacity_count
  end

  def confirmed_capacity_count
    return confirmed_day_trip_signups_with_guests.sum(&:party_capacity_count) if day_trip?
    return confirmed_class_signups.size if class_trip?

    confirmed_signups_with_minors.sum(&:capacity_count)
  end

  def confirmed_uncounted_minor_count
    return 0 if day_trip? || class_trip?

    confirmed_signups_with_minors.sum(&:uncounted_minor_count)
  end

  def uncounted_minor_age_limit
    SiteSetting.current.uncounted_minor_age_limit
  end

  def available_participant_capacity
    [ total_participant_capacity - held_capacity_count, 0 ].max
  end

  def held_capacity_count
    return confirmed_day_trip_signups_with_guests.sum(&:party_capacity_count) if day_trip?
    return confirmed_class_signups.size if class_trip?

    capacity_holding_signups_with_minors.sum(&:capacity_count)
  end

  def capacity_full?
    available_participant_capacity.zero?
  end

  def almost_full?
    return false if capacity_full? || total_participant_capacity.zero?

    confirmed_signup_count.to_f / total_participant_capacity >= ALMOST_FULL_CAPACITY_THRESHOLD
  end

  def waitlisted_signups
    campsite_signups.primary.waitlisted
      .joins(:user)
      .includes(:user, :campsite_signup_minors, guest_signups: :user)
      .order(Arel.sql("CASE WHEN users.member THEN 0 ELSE 1 END"), :created_at)
  end

  def delete_blocked_by_participants?
    campsite_signups.active.exists? || day_trip_signups.active.exists? || class_signups.active.exists?
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def group_fire_night_label
    group_fire_night_planned? ? group_fire_night.titleize : "None"
  end

  def group_campfire_site_label
    return "No Group Campfire" if group_campfire_campsite.blank?

    "#{group_campfire_campsite.campground.name} site #{group_campfire_campsite.site_number}"
  end

  def group_fire_night_planned?
    group_fire_night.present? && group_fire_night != GROUP_FIRE_NIGHT_NONE
  end

  def no_group_campfire?
    group_campfire_campsite.blank? && group_fire_night == GROUP_FIRE_NIGHT_NONE
  end

  def day_trip?
    trip_type == "day_trip"
  end

  def camping?
    trip_type == "camping"
  end

  def class_trip?
    trip_type == "class_trip"
  end

  def trip_type_label
    TRIP_TYPE_LABELS.fetch(trip_type)
  end

  def single_day_event?
    day_trip? || class_trip?
  end

  def climbing_types
    raw_types = self[:climbing_types]
    parsed_types = raw_types.is_a?(Array) ? raw_types : JSON.parse(raw_types.to_s.presence || "[]")

    Array(parsed_types).map(&:to_s)
  rescue JSON::ParserError
    []
  end

  def climbing_types=(values)
    self[:climbing_types] = normalize_climbing_type_values(values).to_json
  end

  def climbing_type_enabled?(type)
    climbing_types.include?(type.to_s)
  end

  def climbing_type_labels
    climbing_types.filter_map { |type| CLIMBING_TYPE_LABELS[type] }
  end

  def sport_climbing?
    climbing_type_enabled?("sport")
  end

  def trad_climbing?
    climbing_type_enabled?("trad")
  end

  def bouldering?
    climbing_type_enabled?("bouldering")
  end

  def cost_dollars
    return if cost_cents.blank?

    BigDecimal(cost_cents.to_s) / 100
  end

  def cost_dollars=(value)
    normalized_value = value.to_s.delete("$,").presence || "0"
    self.cost_cents = (BigDecimal(normalized_value) * 100).round
  rescue ArgumentError
    self.cost_cents = nil
  end

  def safety_reminder
    return SiteSetting.current.day_trip_safety_reminder if day_trip?

    nil
  end

  def lead_signup_count
    confirmed_day_trip_signups.sum(&:lead_count)
  end

  def top_rope_signup_count
    confirmed_day_trip_signups.sum(&:top_rope_count)
  end

  def available_for_day_trip_party?(lead_count:, top_rope_count:)
    return false unless day_trip?

    party_count = lead_count.to_i + top_rope_count.to_i
    party_count.positive? && party_count <= available_participant_capacity
  end

  def available_for_class_signup?
    class_trip? && available_participant_capacity.positive?
  end

  def group_campfire_ready?
    no_group_campfire? || (group_campfire_campsite.present? && group_fire_night_planned?)
  end

  def waitlist_confirmation_campsites_for(signup)
    return [] unless signup&.waitlist_eligible?

    waitlist_open_campsites_for(signup)
  end

  def mark_next_waitlisted_signup_eligible!
    signup = waitlisted_signups.where(waitlist_eligible_at: nil).detect do |waitlisted_signup|
      waitlist_open_campsites_for(waitlisted_signup).any?
    end

    signup&.update!(waitlist_eligible_at: Time.current)
  end

  private

  def ensure_no_active_signups
    return unless delete_blocked_by_participants?

    errors.add(:base, "Cannot delete a trip with participants signed up")
    throw :abort
  end

  def waitlist_open_campsites_for(signup)
    campsites.select { |campsite| campsite.available_for_waitlist_confirmation?(signup) }
  end

  def confirmed_signups_with_minors
    return campsite_signups.select(&:confirmed?) if campsite_signups.loaded?

    campsite_signups.confirmed.includes(:campsite_signup_minors)
  end

  def capacity_holding_signups_with_minors
    return campsite_signups.select(&:capacity_holding?) if campsite_signups.loaded?

    campsite_signups.capacity_holding.includes(:campsite_signup_minors)
  end

  def confirmed_day_trip_signups
    return day_trip_signups.select(&:confirmed?) if day_trip_signups.loaded?

    day_trip_signups.confirmed.includes(:day_trip_signup_minors, guest_signups: :user)
  end

  def confirmed_day_trip_signups_with_guests
    confirmed_day_trip_signups.reject(&:guest?)
  end

  def confirmed_class_signups
    return class_signups.select(&:confirmed?) if class_signups.loaded?

    class_signups.confirmed.includes(:user)
  end

  def normalize_climbing_types
    self.climbing_types = climbing_types
  end

  def normalize_climbing_type_values(values)
    Array(values).flatten.map(&:to_s).map(&:presence).compact.uniq
  end

  def climbing_types_are_known
    unknown_types = climbing_types - CLIMBING_TYPES
    return if unknown_types.empty?

    errors.add(:climbing_types, "include unknown climbing types")
  end

  def day_trip_climbing_types_present
    return unless day_trip? && climbing_types.empty?

    errors.add(:base, "Choose at least one type of climbing for this day trip.")
  end

  def class_capacity_present
    return unless class_trip?
    return if participant_capacity.to_i.positive?

    errors.add(:participant_capacity, "must be greater than 0 for classes")
  end

  def sync_single_day_end_date
    self.end_date = start_date if single_day_event? && start_date.present?
  end

  def single_day_dates_match
    return unless single_day_event?
    return if start_date.blank? || end_date.blank? || start_date == end_date

    errors.add(:end_date, "must match the trip date for #{class_trip? ? 'classes' : 'day trips'}")
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end

  def group_campfire_campsite_belongs_to_trip
    return if group_campfire_campsite.blank?
    return if group_campfire_campsite.trip_id == id

    errors.add(:group_campfire_campsite, "must belong to this trip")
  end
end
