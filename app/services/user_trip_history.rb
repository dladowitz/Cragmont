class UserTripHistory
  SIGNUP_STATUSES = %w[confirmed waitlisted].freeze

  Row = Struct.new(:signup, :signup_type, :ledger_entries, keyword_init: true) do
    def trip
      signup.trip
    end

    def status
      signup.status
    end

    def status_label
      status.titleize
    end

    def status_class
      "#{status}-status"
    end

    def camping?
      signup_type == :camping
    end

    def day_trip?
      signup_type == :day_trip
    end
  end

  def self.for_user(user)
    new(user).rows
  end

  def initialize(user)
    @user = user
  end

  def rows
    (camping_rows + day_trip_rows).sort_by { |row| [ row.trip.start_date, row.trip.name.to_s ] }.reverse
  end

  private

  attr_reader :user

  def camping_rows
    campsite_signups.map do |signup|
      Row.new(
        signup: signup,
        signup_type: :camping,
        ledger_entries: ledger_entries_by_signup_id.fetch(signup.id, [])
      )
    end
  end

  def day_trip_rows
    day_trip_signups.map do |signup|
      Row.new(signup: signup, signup_type: :day_trip, ledger_entries: [])
    end
  end

  def campsite_signups
    @campsite_signups ||= user.campsite_signups
      .where(status: SIGNUP_STATUSES)
      .includes(:trip)
  end

  def day_trip_signups
    @day_trip_signups ||= user.day_trip_signups
      .where(status: SIGNUP_STATUSES)
      .includes(:trip)
  end

  def ledger_entries_by_signup_id
    @ledger_entries_by_signup_id ||= TripTransactionLedger.for_user(user)
      .group_by { |entry| entry.payment.campsite_signup_id }
  end
end
