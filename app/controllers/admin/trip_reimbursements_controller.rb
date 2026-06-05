class Admin::TripReimbursementsController < Admin::BaseController
  before_action :set_trip
  before_action :ensure_trip_not_deleted
  before_action :set_reimbursement, only: %i[edit update destroy]

  def new
    @reimbursement = @trip.trip_reimbursements.build(paid_on: Date.current)
  end

  def create
    @reimbursement = @trip.trip_reimbursements.build(reimbursement_params.merge(recorded_by: current_user))

    if @reimbursement.save
      redirect_to admin_trip_path(@trip), notice: "On belay! Reimbursement was recorded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @reimbursement.update(reimbursement_params)
      redirect_to admin_trip_path(@trip), notice: "Reimbursement was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reimbursement.destroy!
    redirect_to admin_trip_path(@trip), notice: "Reimbursement was removed.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    redirect_to admin_trip_path(@trip), alert: "Restore this trip before making changes.", status: :see_other
  end

  def set_reimbursement
    @reimbursement = @trip.trip_reimbursements.find(params[:id])
  end

  def reimbursement_params
    params.require(:trip_reimbursement).permit(:recipient_name, :amount, :payment_method, :paid_on, :note)
  end
end
