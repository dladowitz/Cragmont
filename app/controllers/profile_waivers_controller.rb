class ProfileWaiversController < ApplicationController
  before_action :require_login

  def new
    @waiver_year = Date.current.year
  end

  def create
    signature = WaiverSignatureData.new(waiver_params[:waiver_signature_data])
    acknowledged_at = waiver_acknowledged_at

    if acknowledged_at.blank?
      redirect_to new_profile_waiver_path, alert: "Please agree to the waiver acknowledgement before signing."
    elsif !signature.valid?
      redirect_to new_profile_waiver_path, alert: "Please sign the waiver before submitting."
    else
      WaiverCreator.new(
        user: current_user,
        signature: signature,
        acknowledged_at: acknowledged_at,
        request: request,
        waiver_year: Date.current.year
      ).create!
      redirect_to profile_path, notice: "On belay! Your current waiver is signed."
    end
  end

  private

  def waiver_params
    params.fetch(:waiver, {}).permit(:waiver_signature_data, :waiver_acknowledged_at)
  end

  def waiver_acknowledged_at
    Time.zone.parse(waiver_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end
end
