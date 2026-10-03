class Api::V1::CampsitesController < Api::V1::BaseController
  CAMPSITE_FIELDS = %i[
    id trip_id campground_id site_number arrival_date checkout_date participant_capacity
    car_capacity registered_by_id registration_fee_cents registration_number notes updated_at
  ].freeze
  WRITABLE_FIELDS = %i[
    campground_id site_number arrival_date checkout_date participant_capacity car_capacity
    registered_by_id registration_fee registration_number notes
  ].freeze

  before_action :set_trip

  def index
    authorize @trip, :show?
    campsites = @trip.campsites.includes(:campground, :registered_by).order(:arrival_date, :site_number, :id)
    render json: { campsites: campsites.map { |campsite| campsite_json(campsite) } }
  end

  def create
    authorize @trip, :manage_campsites?
    return unless editable_trip?

    campsite = @trip.campsites.new(permitted_payload(:campsite, *WRITABLE_FIELDS))
    if campsite.save
      render json: { campsite: campsite_json(campsite) }, status: :created
    else
      validation_error(campsite)
    end
  rescue ArgumentError
    render json: { errors: [ "Registration fee must be a number" ] }, status: :unprocessable_entity
  end

  def update
    authorize @trip, :manage_campsites?
    return unless editable_trip?

    campsite = @trip.campsites.find(params[:id])
    if campsite.update(permitted_payload(:campsite, *WRITABLE_FIELDS))
      render json: { campsite: campsite_json(campsite) }
    else
      validation_error(campsite)
    end
  rescue ArgumentError
    render json: { errors: [ "Registration fee must be a number" ] }, status: :unprocessable_entity
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def editable_trip?
    return true if @trip.camping? && !@trip.deleted?

    render json: { error: "Campsite reservations require an active camping trip" }, status: :conflict
    false
  end

  def campsite_json(campsite)
    campsite.as_json(only: CAMPSITE_FIELDS).merge(
      "campground_name" => campsite.campground.name,
      "registered_by_name" => campsite.registered_by&.full_name
    )
  end
end
