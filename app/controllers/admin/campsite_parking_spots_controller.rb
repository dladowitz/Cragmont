class Admin::CampsiteParkingSpotsController < Admin::BaseController
  before_action :set_trip
  before_action :force_json_for_background_request
  before_action :ensure_trip_not_deleted
  before_action :set_parking_spot

  def update
    authorize @trip, :manage_participants?
    attributes = parking_spot_attributes

    if attributes.blank?
      respond_with_failure("Choose a valid parking assignment.")
      return
    end

    if @parking_spot.update(attributes)
      respond_to do |format|
        format.html { redirect_to admin_trip_path(@trip, anchor: "admin-campsite-#{@parking_spot.campsite_id}"), notice: "On belay! Parking was updated." }
        format.json { render json: parking_spot_response_payload(message: "On belay! Parking was updated.") }
      end
    else
      respond_with_failure(@parking_spot.errors.full_messages.to_sentence)
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    respond_to do |format|
      format.html { redirect_to admin_trip_path(@trip), alert: "Restore this trip before making changes.", status: :see_other }
      format.json { render json: { message: "Restore this trip before making changes." }, status: :unprocessable_entity }
    end
  end

  def force_json_for_background_request
    return unless request.xhr? || request.headers["Accept"].to_s.include?("application/json")

    request.format = :json
  end

  def set_parking_spot
    @parking_spot = CampsiteParkingSpot.joins(:campsite).where(campsites: { trip_id: @trip.id }).find(params[:id])
  end

  def parking_spot_attributes
    assignment = params.dig(:campsite_parking_spot, :assignment)

    case assignment
    when "unassigned"
      { status: "unassigned", assigned_campsite_signup: nil }
    when "first_come_first_serve"
      { status: "first_come_first_serve", assigned_campsite_signup: nil }
    when /\Asignup_(\d+)\z/
      { status: "assigned", assigned_campsite_signup: @trip.campsite_signups.find_by(id: Regexp.last_match(1)) }
    else
      nil
    end
  end

  def respond_with_failure(message)
    respond_to do |format|
      format.html { redirect_to admin_trip_path(@trip, anchor: "admin-campsite-#{@parking_spot.campsite_id}"), alert: message }
      format.json { render json: { message: message }, status: :unprocessable_entity }
    end
  end

  def parking_spot_response_payload(message:)
    campsite = @parking_spot.campsite.reload

    {
      message: message,
      assignment: parking_spot_assignment_value(@parking_spot),
      assigned_count: campsite.assigned_parking_spot_count,
      first_come_first_serve_count: campsite.first_come_first_serve_parking_spot_count
    }
  end

  def parking_spot_assignment_value(spot)
    return "signup_#{spot.assigned_campsite_signup_id}" if spot.assigned?

    spot.status
  end
end
