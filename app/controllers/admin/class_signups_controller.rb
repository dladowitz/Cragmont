class Admin::ClassSignupsController < Admin::BaseController
  before_action :set_trip
  before_action :authorize_trip_participant_management
  before_action :set_signup

  def remove
    participant_name = @signup.user.full_name
    @signup.update!(status: "canceled")
    redirect_to admin_trip_path(@trip), notice: "Off belay! #{participant_name} was removed from this class.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.class_trip.find(params[:trip_id])
  end

  def authorize_trip_participant_management
    authorize @trip, :manage_participants?
  end

  def set_signup
    @signup = @trip.class_signups.active.find(params[:id])
  end
end
