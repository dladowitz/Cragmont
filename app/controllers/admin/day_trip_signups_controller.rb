class Admin::DayTripSignupsController < Admin::BaseController
  before_action :set_trip
  before_action :authorize_trip_participant_management
  before_action :set_signup

  def move_to_waitlist
    if @signup.waitlisted?
      redirect_to admin_trip_path(@trip), alert: "#{@signup.user.full_name} is already on the waitlist."
    elsif @signup.update(status: "waitlisted")
      redirect_to admin_trip_path(@trip), notice: "#{@signup.user.full_name} was moved to the waitlist."
    else
      redirect_to admin_trip_path(@trip), alert: @signup.errors.full_messages.to_sentence
    end
  end

  def move_onto_trip
    if @signup.confirmed?
      redirect_to admin_trip_path(@trip), alert: "#{@signup.user.full_name} is already on the trip."
    elsif @signup.update(status: "confirmed")
      redirect_to admin_trip_path(@trip), notice: "On belay! #{@signup.user.full_name} was moved onto the trip."
    else
      redirect_to admin_trip_path(@trip), alert: @signup.errors.full_messages.to_sentence
    end
  end

  def remove
    participant_name = @signup.user.full_name
    @signup.primary_signup.destroy!
    redirect_to admin_trip_path(@trip), notice: "Off belay! #{participant_name} was removed from this day trip.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.day_trip.find(params[:trip_id])
  end

  def authorize_trip_participant_management
    authorize @trip, :manage_participants?
  end

  def set_signup
    @signup = @trip.day_trip_signups.primary.active.find(params[:id])
  end
end
