class ClimbingPartnerRequestsController < ApplicationController
  before_action :require_login

  def create
    trip = Trip.published_for_public.camping.find(params[:trip_id])
    request = trip.climbing_partner_requests.find_or_initialize_by(user: current_user)

    if request.persisted?
      notice = "You're already on the Climbing Partner Board."
    elsif request.save
      notice = "On belay! You're now on the Climbing Partner Board."
    else
      redirect_to trip_path(trip, anchor: "climbing-partners"), alert: request.errors.full_messages.to_sentence, status: :see_other
      return
    end

    redirect_to trip_path(trip, anchor: "climbing-partners"), notice: notice, status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to trip_path(trip, anchor: "climbing-partners"), notice: "You're already on the Climbing Partner Board.", status: :see_other
  end

  def destroy
    trip = Trip.visible_for_public.camping.find(params[:trip_id])
    request = trip.climbing_partner_requests.find_by(user: current_user)

    request&.destroy!
    notice = request.present? ? "On belay! Your climbing partner request is off the board." : "Your name is already off the Climbing Partner Board."
    redirect_to trip_path(trip, anchor: "climbing-partners"), notice: notice, status: :see_other
  end
end
