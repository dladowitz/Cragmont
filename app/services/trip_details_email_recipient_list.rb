class TripDetailsEmailRecipientList
  Recipient = Struct.new(:signup, :user, :recipient_name, :email, :campsite_label, keyword_init: true)

  def self.call(trip)
    new(trip).call
  end

  def initialize(trip)
    @trip = trip
  end

  def call
    confirmed_signups.map do |signup|
      Recipient.new(
        signup: signup,
        user: signup.user,
        recipient_name: signup.user.full_name,
        email: signup.user.email,
        campsite_label: campsite_label(signup.campsite)
      )
    end
  end

  private

  attr_reader :trip

  def confirmed_signups
    trip.campsite_signups.confirmed
      .includes(:user, campsite: :campground)
      .order(:created_at, :id)
  end

  def campsite_label(campsite)
    return "Not assigned" if campsite.blank?

    "#{campsite.campground.name} site #{campsite.site_number}"
  end
end
