class GymMeetupSchedule
  include ActiveModel::Model
  include ActiveModel::Attributes

  FREQUENCIES = {
    "none" => "Does not repeat",
    "monthly" => "Monthly — same weekday and week of the month",
    "first_third" => "Twice monthly — first and third week",
    "second_fourth" => "Twice monthly — second and fourth week"
  }.freeze

  attr_accessor :trip
  attr_reader :created_trips
  attribute :frequency, :string, default: "none"
  attribute :ends_on, :date

  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validate :repeat_requirements, if: :repeating?

  def repeating?
    frequency != "none"
  end

  def dates
    return [] unless valid? && trip.start_date.present?
    return [ trip.start_date ] unless repeating?

    (trip.start_date..ends_on).select do |date|
      date.wday == trip.start_date.wday && weeks.include?((date.day - 1) / 7 + 1)
    end
  end

  def save
    trip_valid = trip.valid?
    return false unless valid? && trip_valid

    @created_trips = dates.map do |date|
      outing = date == trip.start_date ? trip : trip.dup
      outing.start_date = date
      outing
    end
    Trip.transaction do
      created_trips.each do |outing|
        if outing != trip && trip.day_trip_image.attached?
          outing.day_trip_image.attach(trip.day_trip_image.blob)
        end
        outing.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    trip.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == trip
    false
  end

  private

  def weeks
    case frequency
    when "monthly" then [ (trip.start_date.day - 1) / 7 + 1 ]
    when "first_third" then [ 1, 3 ]
    when "second_fourth" then [ 2, 4 ]
    else []
    end
  end

  def repeat_requirements
    errors.add(:base, "Only gym outings can repeat.") unless trip.gym_outing?
    errors.add(:base, "Choose an Event Coordinator to host these meetups.") if trip.campsite_coordinator.blank?
    if trip.start_date.blank?
      errors.add(:base, "Choose the first meetup date.")
      return
    end

    week = (trip.start_date.day - 1) / 7 + 1
    if week > 4 || !weeks.include?(week)
      errors.add(:base, "Choose a first meetup date in one of the selected weeks (first through fourth).")
    end
    if ends_on.blank?
      errors.add(:ends_on, "is required when repeating")
    elsif ends_on <= trip.start_date || ends_on > trip.start_date.advance(years: 1)
      errors.add(:ends_on, "must be after the first meetup and within one year")
    end
  end
end
