class Admin::CampsitesController < ApplicationController
  before_action :set_trip
  before_action :set_campsite, only: %i[edit update destroy]
  before_action :set_campgrounds, only: %i[new create edit update]

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
    @campsite.destroy
    redirect_to admin_trip_path(@trip), notice: "Campsite was deleted.", status: :see_other
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

  def campsite_params
    params.require(:campsite).permit(
      :campground_id,
      :site_number,
      :arrival_date,
      :checkout_date,
      :participant_capacity,
      :car_capacity,
      :notes
    )
  end
end
