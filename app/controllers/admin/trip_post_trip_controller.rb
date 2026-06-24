class Admin::TripPostTripController < Admin::BaseController
  before_action :set_trip

  def show
    authorize @trip, :show?
    @checklist = TripReadinessChecklist.new(@trip)
    @category = @checklist.post_trip_category
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end
end
