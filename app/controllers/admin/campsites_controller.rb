class Admin::CampsitesController < ApplicationController
  before_action :set_trip
  before_action :set_campsite, only: %i[edit update destroy]
  before_action :set_campgrounds, only: %i[new create edit update]
  before_action :set_users, only: %i[new create edit update]

  def new
    @campsite = @trip.campsites.new
  end

  def edit
  end

  def create
    @campsite = @trip.campsites.new(campsite_params)

    if @campsite.save
      redirect_to admin_trip_path(@trip), notice: "Campsite was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @campsite.update(campsite_params)
      redirect_to admin_trip_path(@trip), notice: "Campsite was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @campsite.destroy
      redirect_to admin_trip_path(@trip), notice: "Campsite was deleted.", status: :see_other
    else
      redirect_to admin_trip_path(@trip), alert: "Cannot delete campsite with participants signed up. Remove them or move to the waitlist first", status: :see_other
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_campsite
    @campsite = @trip.campsites.find(params[:id])
  end

  def set_campgrounds
    @campgrounds = Campground.order(:name)
  end

  def set_users
    @users = User.order(:last_name, :first_name)
  end

  def campsite_params
    params.require(:campsite).permit(
      :campground_id,
      :registered_by_id,
      :registration_number,
      :site_number,
      :arrival_date,
      :checkout_date,
      :participant_capacity,
      :car_capacity,
      :notes
    )
  end
end
