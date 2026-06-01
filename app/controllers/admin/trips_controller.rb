class Admin::TripsController < ApplicationController
  before_action :set_trip, only: %i[show edit update destroy]
  before_action :set_users, only: %i[show new create edit update]

  def index
    @trips = Trip.includes(:campsite_coordinator, { campsite_signups: :campsite_signup_minors }, campsites: :campground).order(start_date: :asc, name: :asc)
  end

  def show
    @campsites = @trip.campsites.includes(:campground, :registered_by, campsite_signups: [ :payments, :user, :campsite_signup_minors, { guest_of_signup: :user } ]).order(:arrival_date, :site_number)
    @waitlisted_signups = @trip.waitlisted_signups
    @trip_participant_user_ids = @trip.campsite_signups.active.distinct.pluck(:user_id)
    @trip_reimbursements = @trip.trip_reimbursements.order(paid_on: :desc, created_at: :desc)
  end

  def new
    @trip = Trip.new
  end

  def edit
  end

  def create
    @trip = Trip.new(trip_params)

    if @trip.save
      redirect_to admin_trip_path(@trip), notice: "Trip was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @trip.update(trip_params)
      redirect_to admin_trip_path(@trip), notice: "Trip was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @trip.campsite_signups.exists?
      redirect_to edit_admin_trip_path(@trip), alert: "Cannot delete a trip with participants signed up", status: :see_other
      return
    end

    @trip.destroy
    redirect_to admin_trips_path, notice: "Trip was deleted.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def trip_params
    params.require(:trip).permit(:name, :location, :start_date, :end_date, :description, :status, :campsite_coordinator_id)
  end

  def set_users
    @users = User.order(:last_name, :first_name)
  end
end
