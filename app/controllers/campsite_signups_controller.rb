class CampsiteSignupsController < ApplicationController
  before_action :require_login
  skip_before_action :require_login, only: %i[guest_password participant_password]

  def create
    trip = Trip.published_for_public.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = trip.campsite_signups.active.find_or_initialize_by(user: current_user)

    if signup.persisted? && confirming_waitlist?
      confirm_waitlisted_signup(trip, campsite, signup)
    elsif signup.persisted? && signing_up_from_waitlist?
      confirm_open_campsite_signup_from_waitlist(trip, campsite, signup)
    elsif signup.persisted? && completing_participant_details?
      complete_participant_details(trip, campsite, signup)
    elsif signup.persisted? && signup.pending_payment?
      redirect_to_current_payment_checkout(signup, trip)
    elsif signup.persisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif completing_participant_details?
      redirect_to trip_path(trip), alert: "You are not a participant on this trip."
    elsif joining_waitlist?
      join_waitlist(trip, campsite, signup)
    else
      create_confirmed_signup(trip, campsite, signup)
    end
  end

  def destroy
    trip = Trip.published_for_public.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = trip.campsite_signups.active.find_by(user: current_user)

    if signup.blank?
      redirect_to trip_path(trip), alert: "You are not signed up for this trip.", status: :see_other
    elsif signup.guest? && signup.primary_signup.current_payment&.refundable?
      redirect_to trip_path(trip), alert: "Guests follow the primary participant signup for paid trips.", status: :see_other
    elsif signup.confirmed? && signup.campsite != campsite
      redirect_to trip_path(trip), alert: "You are not signed up for this campsite.", status: :see_other
    else
      removing_waitlist_signup = signup.waitlisted?
      campsite.lock_signups! if signup.confirmed? && campsite.capacity_full?
      issue_refund = signup.refund_eligible?
      remove_or_cancel_signup!(signup, issue_refund: issue_refund)
      trip.mark_next_waitlisted_signup_eligible! unless removing_waitlist_signup

      notice = removing_waitlist_signup ? "You have been removed from the waitlist." : cancellation_notice(issue_refund)
      redirect_to trip_path(trip), notice: notice, status: :see_other
    end
  end

  def guest_password
    trip = Trip.published_for_public.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = find_guest_completion_signup(trip, campsite)

    if signup.blank?
      redirect_to trip_path(trip), alert: "This guest waiver link is invalid."
    elsif !signup.user.default_password?
      log_in_signup(signup)
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}")
    elsif update_default_password(signup)
      log_in_signup(signup)
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}"), notice: "Your password has been updated."
    else
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}"), alert: signup.user.errors.full_messages.to_sentence
    end
  end

  def participant_password
    trip = Trip.published_for_public.find(params[:trip_id])
    campsite = trip.campsites.find(params[:campsite_id])
    signup = find_participant_completion_signup(trip, campsite)

    if signup.blank?
      redirect_to trip_path(trip), alert: "This participant waiver link is invalid."
    elsif !signup.user.default_password?
      log_in_signup(signup)
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}")
    elsif update_default_password(signup)
      log_in_signup(signup)
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}"), notice: "Your password has been updated."
    else
      redirect_to trip_path(trip, complete_signup: params[:complete_signup], anchor: "campsite-#{campsite.id}"), alert: signup.user.errors.full_messages.to_sentence
    end
  end

  private

  def join_waitlist(trip, campsite, signup)
    minor_attributes = normalized_minor_attributes
    guest_attributes = normalized_guest_attributes

    if !campsite.waitlist_signup_required? && campsite_has_room_for?(campsite, minor_attributes, guest_attributes)
      redirect_to trip_path(trip), alert: "This campsite still has space. Please sign up for the campsite directly."
    elsif signing_up_with_minors? && minor_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter minor information before joining the waitlist."
    elsif signing_up_with_guests? && guest_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter guest information before joining the waitlist."
    elsif create_waitlist_signup(signup, minor_attributes, guest_attributes)
      campsite.lock_signups! if campsite.capacity_full?
      redirect_to trip_path(trip), notice: "You have been added to the waitlist for this trip."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def create_confirmed_signup(trip, campsite, signup)
    minor_attributes = normalized_minor_attributes
    guest_attributes = normalized_guest_attributes

    if !campsite.direct_signup_available?
      redirect_to trip_path(trip), alert: "This campsite is using the waitlist."
    elsif signing_up_with_minors? && minor_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter minor information before signing up."
    elsif signing_up_with_guests? && guest_attributes.empty?
      redirect_to trip_path(trip), alert: "Please enter guest information before signing up."
    elsif !campsite_has_room_for?(campsite, minor_attributes, guest_attributes)
      join_waitlist_from_full_party(trip, signup, minor_attributes, guest_attributes)
    else
      create_signup_with_confirmation(trip, campsite, signup, minor_attributes, guest_attributes)
    end
  end

  def join_waitlist_from_full_party(trip, signup, minor_attributes, guest_attributes)
    if create_waitlist_signup(signup, minor_attributes, guest_attributes)
      redirect_to trip_path(trip), notice: "There is not enough space for your party, so you have been added to the waitlist for this trip."
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def create_signup_with_confirmation(trip, campsite, signup, minor_attributes, guest_attributes)
    return unless ensure_waiver_ready(trip, signup: signup, minor_attributes: minor_attributes, action: "signing up")

    if !attendance_dates_present?(signup)
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    else
      pricing = pricing_for(arrival_date: signup_params[:arrival_date], checkout_date: signup_params[:checkout_date], minor_attributes: minor_attributes, guest_attributes: guest_attributes)

      if pricing.free?
        if create_signup_with_waiver(signup, campsite, @waiver_signature, @waiver_acknowledged_at, minor_attributes, guest_attributes)
          redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
        else
          redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
        end
      elsif create_signup_pending_payment(trip, campsite, signup, @waiver_signature, @waiver_acknowledged_at, minor_attributes, guest_attributes, pricing, previous_signup_status: nil)
        redirect_to_current_payment_checkout(signup, trip)
      else
        redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
      end
    end
  end

  def confirm_waitlisted_signup(trip, campsite, signup)
    return unless ensure_waiver_ready(trip, signup: signup, action: "confirming your spot")

    if !signup.waitlisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif !signup.waitlist_eligible?
      redirect_to trip_path(trip), alert: "You are not eligible to confirm a spot yet."
    elsif !campsite.available_for_waitlist_confirmation?(signup)
      redirect_to trip_path(trip), alert: "That campsite spot is no longer available."
    elsif !attendance_dates_present?(signup)
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    else
      pricing = pricing_for_existing_signup(signup, arrival_date: signup_params[:arrival_date], checkout_date: signup_params[:checkout_date])

      if pricing.free?
        if confirm_waitlist_signup_with_waiver(signup, campsite, @waiver_signature, @waiver_acknowledged_at)
          redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
        else
          redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
        end
      elsif confirm_waitlist_signup_pending_payment(trip, campsite, signup, @waiver_signature, @waiver_acknowledged_at, pricing)
        redirect_to_current_payment_checkout(signup, trip)
      else
        redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
      end
    end
  end

  def confirm_open_campsite_signup_from_waitlist(trip, campsite, signup)
    return unless ensure_waiver_ready(trip, signup: signup, action: "signing up")

    if !signup.waitlisted?
      redirect_to trip_path(trip), alert: "You are already signed up for this trip."
    elsif !campsite.direct_signup_available?
      redirect_to trip_path(trip), alert: "This campsite is using the waitlist."
    elsif !campsite_has_room_for_waitlisted_signup?(campsite, signup)
      redirect_to trip_path(trip), alert: "There is not enough space for your party at this campsite."
    elsif !attendance_dates_present?(signup)
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    else
      pricing = pricing_for_existing_signup(signup, arrival_date: signup_params[:arrival_date], checkout_date: signup_params[:checkout_date])

      if pricing.free?
        if confirm_open_campsite_signup_with_waiver(signup, campsite, @waiver_signature, @waiver_acknowledged_at)
          redirect_to trip_path(trip), notice: "You are confirmed for this campsite."
        else
          redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
        end
      elsif confirm_waitlist_signup_pending_payment(trip, campsite, signup, @waiver_signature, @waiver_acknowledged_at, pricing)
        redirect_to_current_payment_checkout(signup, trip)
      else
        redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
      end
    end
  end

  def complete_participant_details(trip, campsite, signup)
    return unless ensure_waiver_ready(trip, signup: signup, action: "completing your trip details")

    if !signup.confirmed? || signup.campsite != campsite
      redirect_to trip_path(trip), alert: "You are not assigned to this campsite."
    elsif signup.guest?
      if complete_participant_details_with_waiver(signup, @waiver_signature, @waiver_acknowledged_at, update_attendance: false)
        redirect_to trip_path(trip), notice: "Your waiver has been submitted."
      else
        redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
      end
    elsif !attendance_dates_present?(signup)
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    elsif complete_participant_details_with_waiver(signup, @waiver_signature, @waiver_acknowledged_at)
      pricing = pricing_for_existing_signup(signup, arrival_date: signup_params[:arrival_date], checkout_date: signup_params[:checkout_date])

      if pricing.free? || signup.payment_paid_or_settled?
        redirect_to trip_path(trip), notice: "Your trip details have been submitted."
      elsif create_checkout_for_existing_confirmed_signup(trip, campsite, signup, pricing)
        redirect_to_current_payment_checkout(signup, trip)
      else
        redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
      end
    else
      redirect_to trip_path(trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def signup_params
    params.fetch(:campsite_signup, {}).permit(
      :intent,
      :signup_kind,
      :with_minors,
      :with_guests,
      :arrival_date,
      :checkout_date,
      :waiver_signature_data,
      :waiver_acknowledged_at,
      campsite_signup_minors_attributes: %i[first_name last_name age relationship],
      guest_attributes: %i[first_name last_name email phone]
    )
  end

  def guest_password_params
    params.fetch(:user, {}).permit(:password, :password_confirmation)
  end

  def attendance_params
    signup_params.slice(:arrival_date, :checkout_date)
  end

  def attendance_dates_present?(signup)
    signup.errors.add(:arrival_date, :blank) if signup_params[:arrival_date].blank?
    signup.errors.add(:checkout_date, :blank) if signup_params[:checkout_date].blank?

    signup.errors[:arrival_date].empty? && signup.errors[:checkout_date].empty?
  end

  def joining_waitlist?
    signup_params[:intent] == "join_waitlist"
  end

  def confirming_waitlist?
    signup_params[:intent] == "confirm_waitlist"
  end

  def signing_up_from_waitlist?
    signup_params[:intent] == "waitlist_direct_signup"
  end

  def completing_participant_details?
    signup_params[:intent] == "complete_participant_details"
  end

  def waiver_acknowledged_at
    Time.zone.parse(signup_params[:waiver_acknowledged_at].to_s)
  rescue ArgumentError
    nil
  end

  def ensure_waiver_ready(trip, signup:, action:, minor_attributes: [])
    @waiver_required = waiver_required_for?(trip, signup: signup, minor_attributes: minor_attributes)
    @waiver_signature = nil
    @waiver_acknowledged_at = nil
    return true unless @waiver_required

    @waiver_signature = WaiverSignatureData.new(signup_params[:waiver_signature_data])
    @waiver_acknowledged_at = waiver_acknowledged_at

    if @waiver_acknowledged_at.blank?
      redirect_to trip_path(trip), alert: "Please agree to the waiver acknowledgement before #{action}."
      false
    elsif !@waiver_signature.valid?
      redirect_to trip_path(trip), alert: "Please sign the waiver before #{action}."
      false
    else
      true
    end
  end

  def waiver_required_for?(trip, signup:, minor_attributes: [])
    includes_minors = minor_attributes.any? || signup.includes_minors?
    return true if includes_minors

    current_user.current_waiver_for_year(trip.start_date.year).blank?
  end

  def signing_up_with_minors?
    signup_params[:with_minors] == "1" || signup_params[:signup_kind] == "with_minors"
  end

  def signing_up_with_guests?
    signup_params[:with_guests] == "1"
  end

  def normalized_minor_attributes
    return [] unless signing_up_with_minors?

    raw_attributes = signup_params[:campsite_signup_minors_attributes] || {}
    raw_attributes.values.filter_map do |attributes|
      cleaned = attributes.to_h.transform_values { |value| value.to_s.strip }
      next if cleaned.values.all?(&:blank?)

      cleaned
    end
  end

  def normalized_guest_attributes
    return [] unless signing_up_with_guests?

    raw_attributes = signup_params[:guest_attributes] || {}
    raw_attributes.values.filter_map do |attributes|
      cleaned = attributes.to_h.transform_values { |value| value.to_s.strip }
      next if cleaned.values.all?(&:blank?)

      cleaned[:email] = cleaned[:email].to_s.downcase
      cleaned
    end
  end

  def campsite_has_room_for?(campsite, minor_attributes, guest_attributes)
    capacity_count = 1 + minor_attributes.count { |attributes| attributes[:age].to_i >= SiteSetting.current.uncounted_minor_age_limit }
    capacity_count += guest_attributes.size
    campsite.available_participant_capacity >= capacity_count
  end

  def campsite_has_room_for_waitlisted_signup?(campsite, signup)
    campsite.available_participant_capacity >= signup.party_capacity_count
  end

  def pricing_for(arrival_date:, checkout_date:, minor_attributes:, guest_attributes:)
    CampsiteSignupPricing.call(
      arrival_date: arrival_date,
      checkout_date: checkout_date,
      adult_guest_count: guest_attributes.size,
      minor_ages: minor_attributes.map { |attributes| attributes[:age] }
    )
  end

  def pricing_for_existing_signup(signup, arrival_date:, checkout_date:)
    CampsiteSignupPricing.call(
      arrival_date: arrival_date,
      checkout_date: checkout_date,
      adult_guest_count: signup.guest_signups.size,
      minor_ages: signup.campsite_signup_minors.map(&:age)
    )
  end

  def create_signup_pending_payment(trip, campsite, signup, signature, acknowledged_at, minor_attributes, guest_attributes, pricing, previous_signup_status:)
    CampsiteSignup.transaction do
      campsite.lock!
      unless campsite_has_room_for?(campsite, minor_attributes, guest_attributes)
        signup.errors.add(:base, "There is not enough space for your party at this campsite")
        raise ActiveRecord::RecordInvalid.new(signup)
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "pending_payment",
        waitlist_eligible_at: nil
      ))
      minor_attributes.each { |attributes| signup.campsite_signup_minors.build(attributes) }
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
      create_guest_signups!(
        signup,
        guest_attributes,
        status: "pending_payment",
        campsite: campsite,
        arrival_date: signup.arrival_date,
        checkout_date: signup.checkout_date
      )
    end

    create_pending_checkout!(trip, campsite, signup, pricing, previous_signup_status: previous_signup_status)
  rescue ActiveRecord::RecordInvalid, StripeConfigurationError, Stripe::StripeError => error
    signup.errors.add(:base, error.message) if signup.errors.empty?
    false
  end

  def confirm_waitlist_signup_pending_payment(trip, campsite, signup, signature, acknowledged_at, pricing)
    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      unless campsite.available_for_waitlist_confirmation?(signup) || (campsite.direct_signup_available? && campsite_has_room_for_waitlisted_signup?(campsite, signup))
        signup.errors.add(:base, "That campsite spot is no longer available")
        raise ActiveRecord::RecordInvalid.new(signup)
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "pending_payment"
      ))
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
      move_guest_signups_to_campsite!(signup, campsite, signup.arrival_date, signup.checkout_date, status: "pending_payment")
    end

    create_pending_checkout!(trip, campsite, signup, pricing, previous_signup_status: "waitlisted")
  rescue ActiveRecord::RecordInvalid, StripeConfigurationError, Stripe::StripeError => error
    signup.errors.add(:base, error.message) if signup.errors.empty?
    false
  end

  def create_checkout_for_existing_confirmed_signup(trip, campsite, signup, pricing)
    create_pending_checkout!(
      trip,
      campsite,
      signup,
      pricing,
      previous_signup_status: "confirmed",
      expires_at: CampsiteSignupPaymentLifecycle::ADMIN_PENDING_EXPIRATION.from_now
    )
  rescue StripeConfigurationError, Stripe::StripeError => error
    signup.errors.add(:base, error.message)
    false
  end

  def create_pending_checkout!(trip, campsite, signup, pricing, previous_signup_status:, expires_at: CampsiteSignupPaymentLifecycle::DEFAULT_PENDING_EXPIRATION.from_now)
    CampsiteSignupPaymentLifecycle.create_pending_checkout!(
      signup: signup,
      pricing: pricing,
      success_url: trip_url(trip, stripe_checkout: "success", anchor: "campsite-#{campsite.id}"),
      cancel_url: trip_url(trip, stripe_checkout: "canceled", anchor: "campsite-#{campsite.id}"),
      previous_signup_status: previous_signup_status,
      expires_at: expires_at
    )
    true
  end

  def redirect_to_current_payment_checkout(signup, trip)
    payment = signup.current_payment
    checkout_url = verified_stripe_checkout_url(payment&.checkout_url)

    if refresh_current_payment_checkout?(payment, checkout_url)
      CampsiteSignupPaymentLifecycle.refresh_checkout!(
        payment: payment,
        success_url: trip_url(trip, stripe_checkout: "success", anchor: "campsite-#{signup.campsite_id}"),
        cancel_url: trip_url(trip, stripe_checkout: "canceled", anchor: "campsite-#{signup.campsite_id}")
      )
      checkout_url = verified_stripe_checkout_url(payment.reload.checkout_url)
    end

    if checkout_url.present?
      redirect_to checkout_url, allow_other_host: true, status: :see_other
    else
      redirect_to trip_path(trip), alert: "Payment checkout link is not available. Please try again.", status: :see_other
    end
  end

  def verified_stripe_checkout_url(url)
    uri = URI.parse(url.to_s)
    return unless uri.is_a?(URI::HTTPS) && uri.host == "checkout.stripe.com"

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def refresh_current_payment_checkout?(payment, checkout_url)
    return false unless payment&.pending?
    return true if payment.checkout_url.blank?
    return true if payment.checkout_expires_at.present? && !payment.checkout_active?

    checkout_url.blank? && payment.checkout_expires_at.present?
  end

  def remove_or_cancel_signup!(signup, issue_refund:)
    if signup.payments.exists? || signup.pending_payment?
      CampsiteSignupPaymentLifecycle.cancel_or_refund_signup!(
        signup: signup.primary_signup,
        reason: "cancellation_by_participant",
        issue_refund: issue_refund,
        refund_initiated_by: "participant"
      )
    else
      signup.destroy!
    end
  end

  def cancellation_notice(issue_refund)
    return "You have been removed from this campsite." unless issue_refund

    "You have been removed from this campsite. Your refund is headed back to basecamp."
  end

  def create_waitlist_signup(signup, minor_attributes, guest_attributes)
    CampsiteSignup.transaction do
      signup.status = "waitlisted"
      minor_attributes.each { |attributes| signup.campsite_signup_minors.build(attributes) }
      signup.save!
      create_guest_signups!(signup, guest_attributes, status: "waitlisted")
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def create_signup_with_waiver(signup, campsite, signature, acknowledged_at, minor_attributes, guest_attributes)
    CampsiteSignup.transaction do
      campsite.lock!
      unless campsite_has_room_for?(campsite, minor_attributes, guest_attributes)
        signup.errors.add(:base, "There is not enough space for your party at this campsite")
        raise ActiveRecord::RecordInvalid.new(signup)
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "confirmed",
        waitlist_eligible_at: nil
      ))
      minor_attributes.each { |attributes| signup.campsite_signup_minors.build(attributes) }
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
      create_guest_signups!(
        signup,
        guest_attributes,
        status: "confirmed",
        campsite: campsite,
        arrival_date: signup.arrival_date,
        checkout_date: signup.checkout_date
      )
      campsite.lock_signups_if_full!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def confirm_waitlist_signup_with_waiver(signup, campsite, signature, acknowledged_at)
    confirmed = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      unless campsite.available_for_waitlist_confirmation?(signup)
        signup.errors.add(:base, "That campsite spot is no longer available")
        raise ActiveRecord::Rollback
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "confirmed",
        waitlist_eligible_at: nil
      ))
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
      move_guest_signups_to_campsite!(signup, campsite, signup.arrival_date, signup.checkout_date)
      campsite.lock_signups_if_full!
      confirmed = true
    end

    confirmed
  rescue ActiveRecord::RecordInvalid
    false
  end

  def confirm_open_campsite_signup_with_waiver(signup, campsite, signature, acknowledged_at)
    confirmed = false

    CampsiteSignup.transaction do
      signup.lock!
      campsite.lock!

      unless campsite.direct_signup_available? && campsite_has_room_for_waitlisted_signup?(campsite, signup)
        signup.errors.add(:base, "That campsite spot is no longer available")
        raise ActiveRecord::Rollback
      end

      signup.assign_attributes(attendance_params.merge(
        campsite: campsite,
        status: "confirmed",
        waitlist_eligible_at: nil
      ))
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
      move_guest_signups_to_campsite!(signup, campsite, signup.arrival_date, signup.checkout_date)
      campsite.lock_signups_if_full!
      confirmed = true
    end

    confirmed
  rescue ActiveRecord::RecordInvalid
    false
  end

  def complete_participant_details_with_waiver(signup, signature, acknowledged_at, update_attendance: true)
    CampsiteSignup.transaction do
      signup.lock!
      signup.assign_attributes(attendance_params) if update_attendance
      signup.save!
      satisfy_waiver!(signup, signature, acknowledged_at)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def create_guest_signups!(signup, guest_attributes, status:, campsite: nil, arrival_date: nil, checkout_date: nil)
    return if guest_attributes.empty?

    validate_guest_attributes!(signup, guest_attributes)

    guest_attributes.each_with_index do |attributes, index|
      guest_user = guest_user_for!(signup, attributes)
      signup.trip.campsite_signups.create!(
        user: guest_user,
        guest_of_signup: signup,
        guest_position: index + 1,
        status: status,
        campsite: campsite,
        arrival_date: arrival_date,
        checkout_date: checkout_date
      )
    end
  end

  def validate_guest_attributes!(signup, guest_attributes)
    if guest_attributes.size > CampsiteSignup::MAX_GUESTS_PER_SIGNUP
      signup.errors.add(:base, "You can add up to #{CampsiteSignup::MAX_GUESTS_PER_SIGNUP} guests")
    end

    emails = guest_attributes.map { |attributes| attributes[:email].to_s.downcase }
    signup.errors.add(:base, "Guest emails must be unique") if emails.uniq.size != emails.size

    guest_attributes.each_with_index do |attributes, index|
      row_label = "Guest #{index + 1}"
      signup.errors.add(:base, "#{row_label} first name can't be blank") if attributes[:first_name].blank?
      signup.errors.add(:base, "#{row_label} last name can't be blank") if attributes[:last_name].blank?
      signup.errors.add(:base, "#{row_label} email can't be blank") if attributes[:email].blank?
    end

    raise ActiveRecord::RecordInvalid.new(signup) if signup.errors.any?
  end

  def guest_user_for!(signup, attributes)
    email = attributes[:email].to_s.downcase
    user = User.find_by(email: email)

    if user.present?
      if user == current_user || signup.trip.campsite_signups.active.where(user: user).where.not(id: signup.id).exists?
        signup.errors.add(:base, "#{user.full_name} is already signed up for this trip")
        raise ActiveRecord::RecordInvalid.new(signup)
      end

      return user
    end

    default_password = User.generate_default_password

    User.create!(
      first_name: attributes[:first_name],
      last_name: attributes[:last_name],
      email: email,
      phone: attributes[:phone],
      member: false,
      password: default_password,
      password_confirmation: default_password,
      default_password: true
    )
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.full_messages.each { |message| signup.errors.add(:base, "Guest #{message}") } if error.record.is_a?(User)
    raise ActiveRecord::RecordInvalid.new(signup)
  end

  def move_guest_signups_to_campsite!(signup, campsite, arrival_date, checkout_date, status: "confirmed")
    signup.guest_signups.each do |guest_signup|
      guest_signup.update!(
        campsite: campsite,
        status: status,
        arrival_date: arrival_date,
        checkout_date: checkout_date,
        waitlist_eligible_at: nil
      )
    end
  end

  def find_guest_completion_signup(trip, campsite)
    signup = CampsiteSignup.includes(:campsite, :user).find_signed(params[:complete_signup], purpose: :complete_guest_details)
    return if signup.blank?
    return if signup.trip_id != trip.id || signup.campsite_id != campsite.id
    return unless signup.guest?

    signup
  end

  def find_participant_completion_signup(trip, campsite)
    signup = CampsiteSignup.includes(:campsite, :user).find_signed(params[:complete_signup], purpose: :complete_participant_details)
    return if signup.blank?
    return if signup.trip_id != trip.id || signup.campsite_id != campsite.id
    return if signup.guest?

    signup
  end

  def update_default_password(signup)
    signup.user.update(guest_password_params.merge(default_password: false))
  end

  def log_in_signup(signup)
    session[:user_id] = signup.user_id
    @current_user = signup.user
  end

  def satisfy_waiver!(signup, signature, acknowledged_at)
    if signature.present?
      WaiverCreator.new(
        user: current_user,
        signature: signature,
        acknowledged_at: acknowledged_at,
        request: request,
        trip: signup.trip,
        campsite_signup: signup
      ).create!
    else
      signup.update!(waiver: current_user.current_waiver_for_year(signup.trip.start_date.year))
    end
  end
end
