class Admin::TripsController < Admin::BaseController
  before_action :set_trip, only: %i[show edit update destroy restore]
  before_action :ensure_trip_not_deleted, only: %i[edit update destroy]
  before_action :set_users, only: %i[show new create edit update]

  def index
    @showing_deleted_trips = params[:filter] == "deleted"
    trips_scope = @showing_deleted_trips ? Trip.deleted : Trip.active
    @trips = trips_scope.includes(:campsite_coordinator, { campsite_signups: :campsite_signup_minors }, campsites: :campground).order(start_date: :asc, name: :asc)
  end

  def show
    @campsites = @trip.campsites.includes(:campground, :registered_by, campsite_signups: [ { payments: { refunds: :refunded_by } }, :user, :campsite_signup_minors, { guest_of_signup: :user } ]).order(:arrival_date, :site_number)
    @waitlisted_signups = @trip.waitlisted_signups
    @trip_participant_user_ids = @trip.campsite_signups.active.distinct.pluck(:user_id)
    @participant_link_signup = participant_link_signup
    @trip_payment_requests = @trip.trip_payment_requests.order(created_at: :desc)
    @trip_payment_request = trip_payment_request
    @trip_revenue_summary = TripRevenueSummary.call(@trip)
    @trip_expense_refunds = CampsiteSignupPaymentRefund.trip_expense_refund_type
      .joins(campsite_signup_payment: :campsite_signup)
      .where(campsite_signups: { trip_id: @trip.id })
      .includes(:refunded_by, campsite_signup_payment: { campsite_signup: :user })
      .order(refunded_at: :desc, created_at: :desc)
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
    if @trip.delete_blocked_by_participants?
      redirect_to edit_admin_trip_path(@trip), alert: "Cannot delete a trip with participants signed up", status: :see_other
      return
    end

    @trip.soft_delete!
    redirect_to admin_trips_path, notice: "Trip was deleted. Transaction history is still on belay.", status: :see_other
  end

  def restore
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
    params.require(:trip).permit(:name, :location, :start_date, :end_date, :description, :status, :campsite_coordinator_id)
  end

  def set_users
    @users = User.order(:last_name, :first_name)
  end
end
