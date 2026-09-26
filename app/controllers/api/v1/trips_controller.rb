class Api::V1::TripsController < Api::V1::BaseController
  TRIP_FIELDS = %i[
    id name location start_date end_date description status trip_type campsite_coordinator_id
    participant_capacity cost_cents meeting_time end_time meeting_location meeting_location_url
    late_arrival_instructions carpool_meeting_spot weather_url whatsapp_group photo_album_url
    mountain_project_url guide_book_url sun_exposure partner_company_id class_signup_url
    class_original_price class_offers_discount class_discount_code class_discount_amount
    class_discounted_price group_campfire_campsite_id group_fire_night updated_at
  ].freeze

  def index
    authorize Trip
    scope = policy_scope(Trip).order(id: :desc)
    if params[:before_id].present?
      raise ActionController::BadRequest, "before_id must be a positive integer" unless params[:before_id].is_a?(String) && params[:before_id].match?(/\A[1-9]\d*\z/)

      scope = scope.where("id < ?", params[:before_id].to_i)
    end
    trips = scope.limit(100).to_a
    render json: { trips: trips.map { |trip| trip_json(trip) }, next_before_id: (trips.last.id if trips.size == 100) }
  end

  def show
    trip = Trip.find(params[:id])
    authorize trip
    render json: { trip: trip_json(trip) }
  end

  def create
    trip = Trip.new
    authorize trip
    trip.assign_attributes(permitted_payload(:trip, *policy(trip).permitted_attributes.excluding(:day_trip_image)))
    schedule_attributes = params.key?(:gym_meetup_schedule) ? permitted_payload(:gym_meetup_schedule, :frequency, :ends_on) : {}
    schedule = GymMeetupSchedule.new(schedule_attributes.merge(trip: trip))

    if schedule.save
      response.location = api_v1_trip_url(trip)
      render json: { trip: trip_json(trip), created_trip_ids: schedule.created_trips.map(&:id) }, status: :created
    else
      render json: { errors: (trip.errors.full_messages + schedule.errors.full_messages).uniq }, status: :unprocessable_entity
    end
  end

  def update
    trip = Trip.find(params[:id])
    authorize trip
    return render json: { error: "Restore this trip before making changes" }, status: :conflict if trip.deleted?
    if params[:trip].is_a?(ActionController::Parameters) && params[:trip].key?(:campsite_coordinator_id) && !policy(trip).assign_coordinator?
      return render json: { error: "Only global trip admins can change campsite_coordinator_id" }, status: :forbidden
    end

    if trip.update(permitted_payload(:trip, *policy(trip).permitted_attributes.excluding(:day_trip_image)))
      render json: { trip: trip_json(trip) }
    else
      validation_error(trip)
    end
  end

  private

  def trip_json(trip)
    trip.as_json(only: TRIP_FIELDS).merge(
      "climbing_types" => trip.climbing_types,
      "meeting_time" => trip.meeting_time&.strftime("%H:%M"),
      "end_time" => trip.end_time&.strftime("%H:%M"),
      "campsites_path" => api_v1_trip_campsites_path(trip),
      "admin_path" => admin_trip_path(trip)
    )
  end
end
