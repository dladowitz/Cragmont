class TripsController < ApplicationController
  before_action :set_trip, only: :show

  def index
    @trips = Trip.published_for_public.includes(:campsite_coordinator, :campsites)
  end

  def show
    @campsites = @trip.campsites.includes(:campground, campsite_signups: [ :user, :campsite_signup_minors, { guest_of_signup: :user } ]).order(:arrival_date, :site_number)
    @current_signup = @trip.campsite_signups.active.includes(:campsite, :payments).find_by(user: current_user) if user_signed_in?
    @waitlisted_signups = @trip.waitlisted_signups
    @waitlist_confirmation_campsites = @current_signup&.waitlisted? ? @trip.waitlist_confirmation_campsites_for(@current_signup) : []
    @waitlist_confirmation_campsite_ids = @waitlist_confirmation_campsites.map(&:id)
    @completion_signup = participant_details_signup || guest_details_signup
    @show_payment_success_modal = payment_success_return?
  end

  private

  def set_trip
    @trip = Trip.published.find(params[:id])
  end

  def participant_details_signup
    return if params[:complete_signup].blank?

    signup = CampsiteSignup.includes(:campsite).find_signed(params[:complete_signup], purpose: :complete_participant_details)
    return if signup.blank?
    return if signup.trip_id != @trip.id
    return if !signup.confirmed? || signup.campsite.blank?
    if signup.user.default_password?
      @participant_completion_token = params[:complete_signup]
      return signup
    end

    if user_signed_in?
      return if signup.user_id != current_user.id
    else
      log_in_completion_signup(signup)
    end

    return if signup.arrival_date.present? && signup.checkout_date.present? && signup.waiver_signed?

    signup
  end

  def guest_details_signup
    return if params[:complete_signup].blank?

    signup = CampsiteSignup.includes(:campsite, :user).find_signed(params[:complete_signup], purpose: :complete_guest_details)
    return if signup.blank?
    return if signup.trip_id != @trip.id || signup.campsite.blank?
    return unless signup.guest?

    @guest_completion_token = params[:complete_signup]
    return signup if signup.user.default_password?

    log_in_completion_signup(signup)
    return if signup.arrival_date.present? && signup.checkout_date.present? && signup.waiver_signed?

    signup
  end

  def log_in_completion_signup(signup)
    session[:user_id] = signup.user_id
    @current_user = signup.user
    @current_signup = signup
  end

  def payment_success_return?
    params[:stripe_checkout] == "success" && @current_signup&.confirmed?
  end
end
