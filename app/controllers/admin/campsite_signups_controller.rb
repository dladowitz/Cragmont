class Admin::CampsiteSignupsController < ApplicationController
  def make_waitlist_eligible
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.guest?
      redirect_to admin_trip_path(trip), alert: "Guests follow the primary participant signup."
    elsif signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already confirmed for this trip."
    elsif signup.update(waitlist_eligible_at: Time.current)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} can now confirm an open campsite spot."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def revoke_waitlist_eligibility
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already confirmed for this trip."
    elsif signup.update(waitlist_eligible_at: nil)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} can no longer confirm an open campsite spot."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def move_to_campsite
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])
    campsite = trip.campsites.find(move_to_campsite_params[:campsite_id])

    if signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already confirmed for this trip."
    elsif move_waitlisted_signup_to_campsite(signup, campsite)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} was moved to #{campsite.campground.name} site #{campsite.site_number}."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def move_to_waitlist
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.guest?
      redirect_to admin_trip_path(trip), alert: "Guests follow the primary participant signup."
    elsif signup.waitlisted?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already on the waitlist."
    elsif move_confirmed_signup_to_waitlist(signup)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} was moved to the waitlist."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def remove_from_campsite
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])
    campsite = signup.campsite

    if signup.waitlisted?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is not confirmed for a campsite."
    elsif remove_confirmed_signup(signup)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} was removed from #{campsite.campground.name} site #{campsite.site_number}."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  private

  def move_to_campsite_params
    params.require(:campsite_signup).permit(:campsite_id)
  end

  def move_waitlisted_signup_to_campsite(signup, campsite)
    moved = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      signup.update!(
        campsite: campsite,
        status: "confirmed",
        arrival_date: nil,
        checkout_date: nil,
        waitlist_eligible_at: nil
      )
      signup.guest_signups.each do |guest_signup|
        guest_signup.update!(
          campsite: campsite,
          status: "confirmed",
          arrival_date: nil,
          checkout_date: nil,
          waitlist_eligible_at: nil
        )
      end
      campsite.lock_signups_if_full!
      moved = true
    end

    moved
  rescue ActiveRecord::RecordInvalid
    false
  end

  def move_confirmed_signup_to_waitlist(signup)
    moved = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite = signup.campsite
      campsite.lock!
      campsite.lock_signups! if campsite.capacity_full?

      signup.update!(
        campsite: nil,
        status: "waitlisted",
        arrival_date: nil,
        checkout_date: nil,
        waitlist_eligible_at: nil
      )
      signup.guest_signups.each do |guest_signup|
        guest_signup.update!(
          campsite: nil,
          status: "waitlisted",
          arrival_date: nil,
          checkout_date: nil,
          waitlist_eligible_at: nil
        )
      end
      moved = true
    end

    moved
  rescue ActiveRecord::RecordInvalid
    false
  end

  def remove_confirmed_signup(signup)
    removed = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite = signup.campsite
      campsite.lock!
      campsite.lock_signups! if campsite.capacity_full?

      signup.destroy!
      signup.trip.mark_next_waitlisted_signup_eligible!
      removed = true
    end

    removed
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
    false
  end
end
