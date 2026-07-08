class Admin::TripParticipantEmailsController < Admin::BaseController
  before_action :set_trip

  def show
    authorize @trip

    email_list = TripParticipantEmailList.new(@trip)
    @confirmed_participants = email_list.confirmed_participants
    @waitlisted_participants = email_list.waitlisted_participants
    @confirmed_email_addresses = email_list.confirmed_email_addresses
    @waitlisted_email_addresses = email_list.waitlisted_email_addresses
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end
end
