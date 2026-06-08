class Admin::CampsiteSignupsController < Admin::BaseController
  CAMPSITE_COORDINATOR_WAIVED_REASON = "campsite_coordinator_does_not_pay".freeze
  WAIVED_REASON_TYPES = %w[campsite_coordinator other].freeze

  before_action :set_trip
  before_action :ensure_trip_not_deleted

  def create
    trip = @trip
    campsite = trip.campsites.find(add_participant_params[:campsite_id])
    return if invalid_waive_payment_params?(trip)

    if existing_account_participant?
      add_existing_participant(trip, campsite)
    elsif new_account_participant?
      create_participant_account_and_signup(trip, campsite)
    else
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose how this participant is joining the campsite."
    end
  end

  def make_waitlist_eligible
    trip = @trip
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
    trip = @trip
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
    trip = @trip
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
    trip = @trip
    signup = trip.campsite_signups.find(params[:id])

    if signup.guest?
      redirect_to admin_trip_path(trip), alert: "Guests follow the primary participant signup."
    elsif signup.waitlisted?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is already on the waitlist."
    elsif move_confirmed_signup_to_waitlist(signup, issue_refund: issue_refund?)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} was moved to the waitlist."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def remove_from_campsite
    trip = @trip
    signup = trip.campsite_signups.find(params[:id])
    campsite = signup.campsite

    if signup.waitlisted?
      redirect_to admin_trip_path(trip), alert: "#{signup.user.full_name} is not confirmed for a campsite."
    elsif remove_confirmed_signup(signup, issue_refund: issue_refund?)
      redirect_to admin_trip_path(trip), notice: "#{signup.user.full_name} was removed from #{campsite.campground.name} site #{campsite.site_number}."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def remove_from_waitlist
    trip = @trip
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

  def mark_no_payment_needed
    trip = @trip
    signup = trip.campsite_signups.find(params[:id])

    if payment_params[:waived_reason].blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Add a note for why no payment is needed."
    else
      CampsiteSignupPaymentLifecycle.mark_waived!(
        signup: signup,
        pricing: pricing_for(signup),
        reason: payment_params[:waived_reason],
        created_by: current_user
      )
      redirect_to admin_trip_path(trip), notice: "On belay! Payment was marked as not needed for #{signup.user.full_name}."
    end
  end

  def mark_already_paid
    trip = @trip
    signup = trip.campsite_signups.find(params[:id])

    if signup.arrival_date.blank? || signup.checkout_date.blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Add attendance dates before marking payment."
    elsif payment_params[:manual_payment_method].blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose how this participant already paid."
    else
      CampsiteSignupPaymentLifecycle.mark_manual_paid!(
        signup: signup,
        pricing: pricing_for(signup),
        method: payment_params[:manual_payment_method],
        paid_at: manual_paid_at,
        note: payment_params[:note],
        created_by: current_user
      )
      redirect_to admin_trip_path(trip), notice: "On belay! Payment was marked as already paid for #{signup.user.full_name}."
    end
  end

  def create_payment_link
    trip = @trip
    signup = trip.campsite_signups.find(params[:id])

    if signup.arrival_date.blank? || signup.checkout_date.blank? || !signup.waiver_signed?
      redirect_to admin_trip_path(trip), alert: "Share the waiver and date selection link before creating a payment link."
      return
    end

    pricing = pricing_for(signup)
    if pricing.free?
      CampsiteSignupPaymentLifecycle.mark_waived!(
        signup: signup,
        pricing: pricing,
        reason: "No payment due",
        created_by: current_user
      )
      redirect_to admin_trip_path(trip), notice: "No payment is due for #{signup.user.full_name}."
    elsif create_admin_payment_checkout(trip, signup, pricing)
      redirect_to admin_trip_path(trip), notice: "Payment link was created for #{signup.user.full_name}."
    else
      redirect_to admin_trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def update_parking_status
    trip = @trip
    signup = trip.campsite_signups.includes(:user, :campsite).find(params[:id])

    if !signup.confirmed? || signup.campsite.blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Parking can only be assigned to confirmed campsite participants."
    elsif CampsiteSignup::PARKING_STATUSES.exclude?(parking_status_params[:parking_status])
      redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{signup.campsite_id}"), alert: "Wow, that was a whipper. Choose a valid parking status."
    elsif signup.update(parking_status: parking_status_params[:parking_status])
      redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{signup.campsite_id}"), notice: "On belay! Parking was updated for #{signup.user.full_name}."
    else
      redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{signup.campsite_id}"), alert: "Wow, that was a whipper. #{signup.errors.full_messages.to_sentence}."
    end
  end

  def email_participant_link
    trip = @trip
    signup = trip.campsite_signups.includes(:user, :campsite).find(params[:id])

    if signup.user.email.blank?
      message = "Wow, that was a whipper. #{signup.user.full_name} does not have an email address."
      respond_to do |format|
        format.html { redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{signup.campsite_id}"), alert: message }
        format.json { render json: { message: message, button_text: "Email failed" }, status: :unprocessable_entity }
      end
    else
      send_admin_details_link_email(signup)
      message = "On belay! The #{admin_details_link_name(signup)} was emailed to #{signup.user.full_name}."
      respond_to do |format|
        format.html { redirect_to admin_trip_path(trip, anchor: "admin-campsite-#{signup.campsite_id}"), notice: message }
        format.json { render json: { message: message, button_text: "Email sent" } }
      end
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

  def add_participant_params
    params.fetch(:campsite_signup, {}).permit(:campsite_id, :participant_account_status, :user_id, :waive_payment, :waived_reason_type, :waived_reason, new_user: %i[first_name last_name email phone])
  end

  def payment_params
    params.fetch(:payment, {}).permit(:waived_reason, :manual_payment_method, :manual_paid_at, :note, :issue_refund)
  end

  def parking_status_params
    params.require(:campsite_signup).permit(:parking_status)
  end

  def issue_refund?
    ActiveModel::Type::Boolean.new.cast(payment_params[:issue_refund])
  end

  def existing_account_participant?
    add_participant_params[:participant_account_status] == "existing"
  end

  def new_account_participant?
    add_participant_params[:participant_account_status] == "new"
  end

  def waive_payment?
    ActiveModel::Type::Boolean.new.cast(add_participant_params[:waive_payment])
  end

  def campsite_coordinator_waiver?
    waive_payment? && add_participant_params[:waived_reason_type] == "campsite_coordinator"
  end

  def invalid_waive_payment_params?(trip)
    return false unless waive_payment?

    if WAIVED_REASON_TYPES.exclude?(add_participant_params[:waived_reason_type])
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose why this participant's payment is waived."
      return true
    end

    return false unless add_participant_params[:waived_reason_type] == "other" && add_participant_params[:waived_reason].blank?

    redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Add a reason for waiving this participant's payment."
    true
  end

  def add_existing_participant(trip, campsite)
    if add_participant_params[:user_id].blank?
      redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. Choose a participant before stepping onto this campsite."
      return
    end

    user = User.find(add_participant_params[:user_id])
    signup = build_admin_assigned_signup(trip, campsite, user)

    if save_admin_assigned_signup(signup, campsite, waive_payment: waive_payment?)
      redirect_to admin_added_participant_redirect_path(trip, campsite, signup), notice: "On belay! #{user.full_name} was added to #{campsite.campground.name} site #{campsite.site_number}."
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
      save_admin_assigned_signup!(signup, campsite, waive_payment: waive_payment?)
      saved = true
    end

    if saved
      redirect_to admin_added_participant_redirect_path(trip, campsite, signup), notice: "On belay! #{user.full_name}'s account was created and they were added to #{campsite.campground.name} site #{campsite.site_number}."
    end
  rescue ActiveRecord::RecordInvalid => error
    record = error.record == signup ? signup : user
    redirect_to admin_trip_path(trip), alert: "Wow, that was a whipper. #{record.errors.full_messages.to_sentence}"
  end

  def build_admin_created_user
    user_attributes = add_participant_params.fetch(:new_user, {})
    default_password = User.generate_default_password

    User.new(
      user_attributes.merge(
        member: false,
        password: default_password,
        password_confirmation: default_password,
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

    existing_user.present? && trip.campsite_signups.active.exists?(user: existing_user)
  end

  def pricing_for(signup)
    CampsiteSignupPricing.call(
      arrival_date: signup.arrival_date,
      checkout_date: signup.checkout_date,
      adult_guest_count: signup.guest_signups.size,
      minor_ages: signup.campsite_signup_minors.map(&:age)
    )
  end

  def manual_paid_at
    Time.zone.parse(payment_params[:manual_paid_at].presence || Time.current.to_s)
  rescue ArgumentError
    Time.current
  end

  def create_admin_payment_checkout(trip, signup, pricing)
    CampsiteSignupPaymentLifecycle.create_pending_checkout!(
      signup: signup,
      pricing: pricing,
      success_url: admin_trip_url(trip, stripe_checkout: "success"),
      cancel_url: admin_trip_url(trip, stripe_checkout: "canceled"),
      created_by: current_user,
      previous_signup_status: signup.status,
      expires_at: CampsiteSignupPaymentLifecycle::ADMIN_PENDING_EXPIRATION.from_now
    )
    true
  rescue StripeConfigurationError, Stripe::StripeError => error
    signup.errors.add(:base, error.message)
    false
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

  def save_admin_assigned_signup(signup, campsite, waive_payment: false)
    save_admin_assigned_signup!(signup, campsite, waive_payment: waive_payment)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def save_admin_assigned_signup!(signup, campsite, waive_payment: false)
    CampsiteSignup.transaction do
      campsite.lock!
      signup.save!
      signup.update!(status: "confirmed", waitlist_eligible_at: nil)
      apply_admin_waived_payment!(signup) if waive_payment
      campsite.lock_signups_if_full!
    end
  end

  def send_admin_details_link_email(signup)
    return if signup.user.email.blank?

    mail_params = {
      signup: signup,
      waiver_url: details_completion_url(signup)
    }

    if signup.guest?
      mail_params[:primary_participant] = signup.guest_of_signup.user
    else
      mail_params[:added_by] = current_user
      mail_params[:waiver_instruction] = admin_added_participant_link_instruction(signup)
    end

    GuestWaiverMailer.with(mail_params).needed.deliver_now
  end

  def details_completion_url(signup)
    trip_url(signup.trip, complete_signup: signup.signed_id(purpose: details_completion_purpose(signup)), anchor: "campsite-#{signup.campsite_id}")
  end

  def details_completion_purpose(signup)
    signup.guest? ? :complete_guest_details : :complete_participant_details
  end

  def admin_added_participant_redirect_path(trip, campsite, signup)
    admin_trip_path(trip, participant_link_signup: signup.signed_id(purpose: :admin_participant_link), anchor: "admin-campsite-#{campsite.id}")
  end

  def admin_added_participant_link_instruction(signup)
    return "Before tying in you'll need to sign the waiver and choose the dates you'll be there." if signup.payment_paid_or_settled?

    "Before tying in you'll need to choose dates, sign the waiver, and pay for the trip."
  end

  def admin_details_link_name(signup)
    return "waiver link" if signup.guest?
    return "date selection and waiver link" if signup.payment_paid_or_settled?

    "date selection, waiver, and payment link"
  end

  def apply_admin_waived_payment!(signup)
    signup.trip.update!(campsite_coordinator: signup.user) if campsite_coordinator_waiver?
    CampsiteSignupPaymentLifecycle.mark_waived!(
      signup: signup,
      pricing: CampsiteSignupPricing.zero,
      reason: waived_payment_reason,
      created_by: current_user
    )
  end

  def waived_payment_reason
    return CAMPSITE_COORDINATOR_WAIVED_REASON if campsite_coordinator_waiver?

    add_participant_params[:waived_reason]
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
        waitlist_eligible_at: nil,
        parking_status: "first_come_first_serve"
      )
      signup.guest_signups.each do |guest_signup|
        guest_signup.update!(
          campsite: campsite,
          status: "confirmed",
          arrival_date: nil,
          checkout_date: nil,
          waitlist_eligible_at: nil,
          parking_status: "first_come_first_serve"
        )
      end
      campsite.lock_signups_if_full!
      moved = true
    end

    moved
  rescue ActiveRecord::RecordInvalid
    false
  end

  def move_confirmed_signup_to_waitlist(signup, issue_refund:)
    moved = false
    CampsiteSignupPaymentLifecycle.refund_payment_for!(signup: signup, reason: "moved_to_waitlist_by_admin", initiated_by: "admin", refunded_by: current_user) if issue_refund

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
        waitlist_eligible_at: nil,
        parking_status: "first_come_first_serve"
      )
      signup.guest_signups.each do |guest_signup|
        guest_signup.update!(
          campsite: nil,
          status: "waitlisted",
          arrival_date: nil,
          checkout_date: nil,
          waitlist_eligible_at: nil,
          parking_status: "first_come_first_serve"
        )
      end
      moved = true
    end

    moved
  rescue ActiveRecord::RecordInvalid
    false
  end

  def remove_confirmed_signup(signup, issue_refund:)
    removed = false
    paid_signup = signup.primary_signup.payments.exists?

    CampsiteSignup.transaction do
      signup.lock!
      campsite = signup.campsite
      campsite.lock!
      campsite.lock_signups! if campsite.capacity_full?

      if paid_signup
        CampsiteSignupPaymentLifecycle.cancel_or_refund_signup!(
          signup: signup,
          reason: "removed_by_admin",
          issue_refund: issue_refund,
          refund_initiated_by: "admin",
          refunded_by: current_user
        )
      else
        signup.destroy!
      end
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
