class Admin::TripsController < Admin::BaseController
  TRIP_FILTER_STATUSES = (Trip::STATUSES + [ "deleted" ]).freeze
  DEFAULT_TRIP_FILTER_STATUSES = %w[draft published].freeze

  before_action :set_trip, only: %i[show edit update destroy restore]
  before_action :ensure_trip_not_deleted, only: %i[edit update destroy]
  before_action :set_users, only: %i[show new create edit update]

  def index
    authorize Trip
    @selected_statuses = selected_trip_statuses
    trips_scope = filtered_trips_scope(policy_scope(Trip))
    @trips = trips_scope.includes(:campsite_coordinator, { campsite_signups: :campsite_signup_minors }, campsites: :campground).order(start_date: :asc, name: :asc)
  end

  def show
    authorize @trip
    if @trip.day_trip?
      @campsites = []
      @waitlisted_signups = []
      @day_trip_signups = @trip.day_trip_signups.confirmed.primary.includes(:user, :day_trip_signup_minors, guest_signups: :user).order(:created_at)
      @day_trip_waitlisted_signups = @trip.day_trip_signups.waitlisted.primary.includes(:user, :day_trip_signup_minors, guest_signups: :user).order(:created_at)
    else
      @campsites = @trip.campsites
        .includes(
          :campground,
          :registered_by,
          :registration_reimbursed_by,
          :registration_reimbursement_recorded_by,
          campsite_signups: [ { payments: { refunds: :refunded_by } }, :user, :campsite_signup_minors, { guest_of_signup: :user } ]
        )
        .order(:arrival_date, :site_number)
      @waitlisted_signups = @trip.waitlisted_signups
      @day_trip_signups = []
      @day_trip_waitlisted_signups = []
    end
    @trip_participant_user_ids = if @trip.day_trip?
      @trip.day_trip_signups.active.distinct.pluck(:user_id)
    else
      @trip.campsite_signups.active.distinct.pluck(:user_id)
    end
    @participant_link_signup = participant_link_signup
    @trip_payment_requests = @trip.trip_payment_requests.order(created_at: :desc)
    @trip_payment_request = trip_payment_request
    @trip_details_email = @trip.trip_details_email
    @trip_revenue_summary = TripRevenueSummary.call(@trip)
    @trip_readiness_checklist = TripReadinessChecklist.new(@trip)
    @trip_readiness_categories = @trip_readiness_checklist.readiness_categories
    @reimbursable_campsites = @campsites.select { |campsite| campsite.registration_fee_cents.positive? }
    @reimbursed_campsites_count = @reimbursable_campsites.count(&:registration_reimbursed?)
    @trip_expense_refunds = CampsiteSignupPaymentRefund.trip_expense_refund_type
      .joins(campsite_signup_payment: :campsite_signup)
      .where(campsite_signups: { trip_id: @trip.id })
      .includes(:refunded_by, campsite_signup_payment: { campsite_signup: :user })
      .order(refunded_at: :desc, created_at: :desc)
  end

  def new
    if params[:trip_type].blank?
      @trip_type_choice_required = true
      @trip = Trip.new
      authorize @trip
      return
    end

    @trip = Trip.new(
      trip_type: selected_new_trip_type,
      late_arrival_instructions: Trip::DEFAULT_LATE_ARRIVAL_INSTRUCTIONS,
      cost_cents: 0
    )
    authorize @trip
  end

  def edit
    authorize @trip
  end

  def create
    @trip = Trip.new(trip_params)
    authorize @trip

    if @trip.save
      redirect_to admin_trip_path(@trip), notice: "Trip was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @trip

    if @trip.update(trip_params)
      redirect_to admin_trip_path(@trip), notice: "Trip was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @trip

    if @trip.delete_blocked_by_participants?
      redirect_to edit_admin_trip_path(@trip), alert: "Cannot delete a trip with participants signed up", status: :see_other
      return
    end

    @trip.soft_delete!
    redirect_to admin_trips_path, notice: "Trip was deleted. Transaction history is still on belay.", status: :see_other
  end

  def restore
    authorize @trip

    @trip.restore!
    redirect_to admin_trip_path(@trip), notice: "On belay! Trip was restored.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def participant_link_signup
    return if params[:participant_link_signup].blank?

    signup = CampsiteSignup.includes(:user, :campsite).find_signed(params[:participant_link_signup], purpose: :admin_participant_link)
    return if signup.blank? || signup.trip_id != @trip.id || signup.campsite.blank?

    signup
  end

  def trip_payment_request
    return if params[:payment_request].blank?

    payment_request = TripPaymentRequest.find_signed(params[:payment_request], purpose: :admin_trip_payment_request)
    return if payment_request.blank? || payment_request.trip_id != @trip.id

    payment_request
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    redirect_to admin_trip_path(@trip), alert: "Restore this trip before making changes.", status: :see_other
  end

  def trip_params
    params.require(:trip).permit(policy(@trip || Trip).permitted_attributes)
  end

  def selected_new_trip_type
    params[:trip_type].presence_in(Trip::TRIP_TYPES) || "camping"
  end

  def set_users
    @users = User.order(:first_name, :last_name)
  end

  def selected_trip_statuses
    return [ "deleted" ] if params[:filter] == "deleted"
    return DEFAULT_TRIP_FILTER_STATUSES unless params[:filters].present?

    Array(params[:status]).select { |status| status.in?(TRIP_FILTER_STATUSES) }
  end

  def filtered_trips_scope(base_scope)
    active_statuses = @selected_statuses & Trip::STATUSES
    trips_scope = base_scope.none
    trips_scope = trips_scope.or(base_scope.active.where(status: active_statuses)) if active_statuses.any?
    trips_scope = trips_scope.or(base_scope.deleted) if @selected_statuses.include?("deleted")
    trips_scope
  end
end
