class TripsController < ApplicationController
  ARCHIVED_TRIPS_PER_PAGE = 5

  before_action :set_trip, only: :show

  def index
    @trips = Trip.published_for_public.includes(:campsite_coordinator, :campsites)
    archived_trips_scope = Trip.archived_for_public.includes(:campsite_coordinator, :campsites)

    @archived_current_page = [ params[:archived_page].to_i, 1 ].max
    @total_archived_trips = archived_trips_scope.count
    @archived_total_pages = (@total_archived_trips.to_f / ARCHIVED_TRIPS_PER_PAGE).ceil
    @archived_total_pages = 1 if @archived_total_pages.zero?
    @archived_current_page = @archived_total_pages if @archived_current_page > @archived_total_pages

    @archived_trips = archived_trips_scope
      .offset((@archived_current_page - 1) * ARCHIVED_TRIPS_PER_PAGE)
      .limit(ARCHIVED_TRIPS_PER_PAGE)
  end

  def what_to_expect
    @content_page = ContentPage.current!("what_to_expect")
  end

  def show
    @campsites = @trip.campsites.includes(:campground, campsite_signups: [ :user, :campsite_signup_minors, { guest_of_signup: :user } ]).order(:arrival_date, :site_number)
    @current_signup = @trip.campsite_signups.active.includes(:campsite, :payments, { guest_of_signup: :user }, guest_signups: [ :user, :campsite ]).find_by(user: current_user) if user_signed_in?
    @waitlisted_signups = @trip.waitlisted_signups
    @waitlist_confirmation_campsites = @current_signup&.waitlisted? ? @trip.waitlist_confirmation_campsites_for(@current_signup) : []
    @waitlist_confirmation_campsite_ids = @waitlist_confirmation_campsites.map(&:id)
    @completion_signup = participant_details_signup || guest_details_signup
    @show_payment_success_modal = payment_success_return?
    if @show_payment_success_modal
      missing_waiver_signups = payment_success_missing_waiver_signups
      @payment_success_missing_waiver_links = payment_success_missing_waiver_links(missing_waiver_signups)
    end
  end

  private

  def set_trip
    @trip = Trip.visible_for_public.find(params[:id])
  end

  def participant_details_signup
    return if params[:complete_signup].blank?

    signup = CampsiteSignup.includes(:campsite).find_signed(params[:complete_signup], purpose: :complete_participant_details)
    return if signup.blank?
    return if signup.trip_id != @trip.id
    return if !signup.confirmed? || signup.campsite.blank?
    @participant_completion_token = params[:complete_signup]
    if signup.user.default_password?
      log_in_completion_signup(signup)
    elsif user_signed_in?
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

  def payment_success_missing_waiver_signups
    return [] if @current_signup.blank? || @current_signup.guest?

    @current_signup.guest_signups.confirmed.includes(:user, :campsite).reject(&:waiver_signed?)
  end

  def payment_success_missing_waiver_links(signups)
    signups.map do |signup|
      {
        name: signup.user.full_name,
        waiver_path: guest_waiver_path(signup),
        waiver_url: guest_waiver_url(signup),
        email_path: trip_guest_waiver_email_path(@trip, signup)
      }
    end
  end

  def guest_waiver_path(signup)
    trip_path(@trip, complete_signup: signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{signup.campsite_id}")
  end

  def guest_waiver_url(signup)
    trip_url(@trip, complete_signup: signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{signup.campsite_id}")
  end
end
