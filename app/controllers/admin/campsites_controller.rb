class Admin::CampsitesController < Admin::BaseController
  before_action :set_trip
  before_action :ensure_trip_not_deleted
  before_action :set_campsite, only: %i[edit update destroy record_registration_reimbursement]
  before_action :set_campgrounds, only: %i[new create edit update]
  before_action :set_users, only: %i[new create edit update]

  def new
    authorize @trip, :manage_campsites?
    @campsite = @trip.campsites.new
  end

  def edit
    authorize @trip, :manage_campsites?
  end

  def create
    authorize @trip, :manage_campsites?
    @campsite = @trip.campsites.new(campsite_params)

    if @campsite.save
      redirect_to admin_trip_path(@trip), notice: "Campsite was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @trip, :manage_campsites?

    if @campsite.update(campsite_params)
      redirect_to admin_trip_path(@trip), notice: "Campsite was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @trip, :manage_campsites?

    if @campsite.destroy
      redirect_to admin_trip_path(@trip), notice: "Campsite was deleted.", status: :see_other
    else
      redirect_to admin_trip_path(@trip), alert: "Cannot delete campsite with participants signed up. Remove them or move to the waitlist first", status: :see_other
    end
  end

  def record_registration_reimbursement
    authorize @trip, :manage_payments?

    if @campsite.update(registration_reimbursement_params.merge(registration_reimbursement_recorded_by: current_user))
      redirect_to admin_trip_path(@trip), notice: "On belay! Campsite reimbursement was recorded."
    else
      redirect_to admin_trip_path(@trip), alert: "Wow, that was a whipper. #{@campsite.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    redirect_to admin_trip_path(@trip), alert: "Restore this trip before making changes.", status: :see_other
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
      :registration_fee,
      :registration_number,
      :site_number,
      :arrival_date,
      :checkout_date,
      :participant_capacity,
      :car_capacity,
      :notes
    )
  end

  def registration_reimbursement_params
    params.require(:campsite).permit(
      :registration_reimbursed_at,
      :registration_reimbursed_by_id,
      :registration_reimbursement_method,
      :registration_reimbursement_notes
    )
  end
end
