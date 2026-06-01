class Admin::CampsiteSignupsController < ApplicationController
  def create
    trip = Trip.find(params[:trip_id])
    campsite = trip.campsites.find(add_participant_params[:campsite_id])

    if existing_account_participant?
      add_existing_participant(trip, campsite)
    elsif new_account_participant?
      create_participant_account_and_signup(trip, campsite)
    else
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose how this participant is joining the campsite."
    end
  end

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

  def remove_from_waitlist
    trip = Trip.find(params[:trip_id])
    signup = trip.campsite_signups.find(params[:id])

    if signup.guest?
      redirect_to admin_trip_path(trip), alert: "Guests follow the primary participant signup."
    elsif signup.confirmed?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. #{signup.user.full_name} is not on the waitlist."
    elsif remove_waitlisted_signup(signup)
      redirect_to admin_trip_path(trip), notice: "Off belay! #{signup.user.full_name} was removed from the waitlist."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  private

  def add_participant_params
    params.fetch(:campsite_signup, {}).permit(:campsite_id, :participant_account_status, :user_id, new_user: %i[first_name last_name email phone])
  end

  def existing_account_participant?
    add_participant_params[:participant_account_status] == "existing"
  end

  def new_account_participant?
    add_participant_params[:participant_account_status] == "new"
  end

  def add_existing_participant(trip, campsite)
    if add_participant_params[:user_id].blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose a participant before stepping onto this campsite."
      return
    end

    user = User.find(add_participant_params[:user_id])
    signup = build_admin_assigned_signup(trip, campsite, user)

    if save_admin_assigned_signup(signup, campsite)
      redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{campsite.id}"), notice: "On belay! #{user.full_name} was added to #{campsite.campground.name} site #{campsite.site_number}."
    else
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. #{signup.errors.full_messages.to_sentence}"
    end
  end

  def create_participant_account_and_signup(trip, campsite)
    user = build_admin_created_user

    if missing_new_user_fields(user).any?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. #{missing_new_user_fields(user).to_sentence} can't be blank."
      return
    end

    if existing_user_already_on_trip?(trip, user.email)
      redirect_to admin_trip_path(trip), alert: "We saw that foot slip. This person is already signed up for the trip"
      return
    end

    signup = nil
    saved = false

    User.transaction do
      user.save!
      signup = build_admin_assigned_signup(trip, campsite, user)
      save_admin_assigned_signup!(signup, campsite)
      saved = true
    end

    if saved
      redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{campsite.id}"), notice: "On belay! #{user.full_name}'s account was created and they were added to #{campsite.campground.name} site #{campsite.site_number}."
    end
  rescue ActiveRecord::RecordInvalid => error
    record = error.record == signup ? signup : user
    redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. #{record.errors.full_messages.to_sentence}"
  end

  def build_admin_created_user
    user_attributes = add_participant_params.fetch(:new_user, {})

    User.new(
      user_attributes.merge(
        member: false,
        password: User::DEFAULT_GUEST_PASSWORD,
        password_confirmation: User::DEFAULT_GUEST_PASSWORD,
        default_password: true
      )
    )
  end

  def missing_new_user_fields(user)
    {
      first_name: "First name",
      last_name: "Last name",
      email: "Email"
    }.filter_map do |attribute, label|
      label if user.public_send(attribute).blank?
    end
  end

  def existing_user_already_on_trip?(trip, email)
    existing_user = User.find_by(email: email.to_s.strip.downcase)

    existing_user.present? && trip.campsite_signups.exists?(user: existing_user)
  end

  def build_admin_assigned_signup(trip, campsite, user)
    trip.campsite_signups.build(
      user: user,
      campsite: campsite,
      status: "waitlisted",
      arrival_date: nil,
      checkout_date: nil
    )
  end

  def save_admin_assigned_signup(signup, campsite)
    save_admin_assigned_signup!(signup, campsite)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def save_admin_assigned_signup!(signup, campsite)
    CampsiteSignup.transaction do
      campsite.lock!
      signup.save!
      signup.update!(status: "confirmed", waitlist_eligible_at: nil)
      campsite.lock_signups_if_full!
    end
  end

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

  def remove_waitlisted_signup(signup)
    removed = false

    CampsiteSignup.transaction do
      signup.lock!
      trip = signup.trip
      advance_waitlist = signup.waitlist_eligible?

      signup.destroy!
      trip.mark_next_waitlisted_signup_eligible! if advance_waitlist
      removed = true
    end

    removed
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
    false
  end
end
