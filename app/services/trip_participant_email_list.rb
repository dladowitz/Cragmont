class TripParticipantEmailList
  Participant = Struct.new(:signup, :user, :name, :email, keyword_init: true)

  def initialize(trip)
    @trip = trip
  end

  def confirmed_participants
    @confirmed_participants ||= participants_for_status("confirmed")
  end

  def waitlisted_participants
    @waitlisted_participants ||= participants_for_status("waitlisted")
  end

  def confirmed_email_addresses
    email_addresses_for(confirmed_participants)
  end

  def waitlisted_email_addresses
    email_addresses_for(waitlisted_participants)
  end

  private

  attr_reader :trip

  def participants_for_status(status)
    signup_scope(status).map do |signup|
      Participant.new(
        signup: signup,
        user: signup.user,
        name: signup.user.full_name,
        email: signup.user.email
      )
    end
  end

  def signup_scope(status)
    if trip.day_trip?
      trip.day_trip_signups.public_send(status).includes(:user).order(:created_at, :id)
    else
      trip.campsite_signups.public_send(status).includes(:user).order(:created_at, :id)
    end
  end

  def email_addresses_for(participants)
    participants.filter_map { |participant| participant.email.presence }.uniq
  end
end
