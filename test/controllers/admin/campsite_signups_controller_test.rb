require "test_helper"

class Admin::CampsiteSignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  FakeStripeCheckoutSessionCreator = Struct.new(:payment, :success_url, :cancel_url, keyword_init: true) do
    def call
      payment.update!(
        stripe_checkout_session_id: "cs_admin_test_#{payment.id}",
        checkout_url: "https://checkout.stripe.com/c/pay/admin-#{payment.id}",
        expires_at: 30.minutes.from_now
      )
      payment
    end
  end

  test "can add existing account participant directly to campsite" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)

    assert_difference "CampsiteSignup.count", 1 do
      post admin_trip_campsite_signups_url(trip), params: {
        campsite_signup: {
          campsite_id: campsite.id,
          participant_account_status: "existing",
          user_id: users(:sam).id
        }
      }
    end

    assert_redirected_to admin_trip_url(trip, anchor: "admin-campsite-#{campsite.id}")
    assert_equal "On belay! Sam Lee was added to Upper Pines site A12.", flash[:notice]
    signup = CampsiteSignup.order(:created_at).last
    assert signup.confirmed?
    assert_equal trip, signup.trip
    assert_equal campsite, signup.campsite
    assert_equal users(:sam), signup.user
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waiver_signed?
  end

  test "can create account and add participant directly to campsite" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)

    assert_difference "User.count", 1 do
      assert_difference "CampsiteSignup.count", 1 do
        post admin_trip_campsite_signups_url(trip), params: {
          campsite_signup: {
            campsite_id: campsite.id,
            participant_account_status: "new",
            new_user: {
              first_name: "Morgan",
              last_name: "Chen",
              email: "morgan-direct@example.com",
              phone: "555-0199"
            }
          }
        }
      end
    end

    user = User.find_by!(email: "morgan-direct@example.com")
    signup = CampsiteSignup.find_by!(trip: trip, user: user)
    assert_redirected_to admin_trip_url(trip, anchor: "admin-campsite-#{campsite.id}")
    assert_equal "On belay! Morgan Chen's account was created and they were added to Upper Pines site A12.", flash[:notice]
    assert_equal "555-0199", user.phone
    assert user.default_password?
    assert user.authenticate(User::DEFAULT_GUEST_PASSWORD)
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
  end

  test "direct campsite add can confirm participant over capacity" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      create_campsite_signup!(
        campsite: campsite,
        user: User.create!(
          first_name: "Full",
          last_name: "Camper#{index}",
          email: "full-direct-#{index}@example.com",
          password: "password"
        )
      )
    end
    participant = User.create!(
      first_name: "Over",
      last_name: "Capacity",
      email: "over-capacity@example.com",
      password: "password"
    )

    assert_difference "CampsiteSignup.confirmed.count", 1 do
      post admin_trip_campsite_signups_url(trip), params: {
        campsite_signup: {
          campsite_id: campsite.id,
          participant_account_status: "existing",
          user_id: participant.id
        }
      }
    end

    assert_redirected_to admin_trip_url(trip, anchor: "admin-campsite-#{campsite.id}")
    signup = CampsiteSignup.find_by!(trip: trip, user: participant)
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert campsite.reload.signups_locked?
  end

  test "does not add existing account participant without selecting user" do
    assert_no_difference "CampsiteSignup.count" do
      post admin_trip_campsite_signups_url(trips(:yosemite)), params: {
        campsite_signup: {
          campsite_id: campsites(:yosemite_a).id,
          participant_account_status: "existing",
          user_id: ""
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. Choose a participant before stepping onto this campsite.", flash[:alert]
  end

  test "does not create account without required participant fields" do
    assert_no_difference [ "User.count", "CampsiteSignup.count" ] do
      post admin_trip_campsite_signups_url(trips(:yosemite)), params: {
        campsite_signup: {
          campsite_id: campsites(:yosemite_a).id,
          participant_account_status: "new",
          new_user: {
            first_name: "Morgan",
            last_name: "",
            email: ""
          }
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. Last name and Email can't be blank.", flash[:alert]
  end

  test "does not add participant already signed up for trip" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post admin_trip_campsite_signups_url(trips(:yosemite)), params: {
        campsite_signup: {
          campsite_id: campsites(:yosemite_b).id,
          participant_account_status: "existing",
          user_id: users(:sam).id
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. User is already signed up for this trip", flash[:alert]
  end

  test "new account path shows friendly message when email is already signed up for trip" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference [ "User.count", "CampsiteSignup.count" ] do
      post admin_trip_campsite_signups_url(trips(:yosemite)), params: {
        campsite_signup: {
          campsite_id: campsites(:yosemite_b).id,
          participant_account_status: "new",
          new_user: {
            first_name: "Samuel",
            last_name: "Duplicate",
            email: " SAM@example.com ",
            phone: "555-0190"
          }
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "We saw that foot slip. This person is already signed up for the trip", flash[:alert]
  end

  test "can mark waitlisted participant eligible" do
    participant = User.create!(
      first_name: "Willa",
      last_name: "Wait",
      email: "eligible-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: participant)

    patch make_waitlist_eligible_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert signup.reload.waitlist_eligible?
  end

  test "does not mark confirmed participant eligible" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    patch make_waitlist_eligible_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_not signup.reload.waitlist_eligible?
    assert_equal "Sam Lee is already confirmed for this trip.", flash[:alert]
  end

  test "can revoke waitlisted participant signup ability" do
    participant = User.create!(
      first_name: "Willa",
      last_name: "Wait",
      email: "revoke-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: participant, waitlist_eligible_at: Time.current)

    patch revoke_waitlist_eligibility_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_not signup.reload.waitlist_eligible?
    assert_equal "Willa Wait can no longer confirm an open campsite spot.", flash[:notice]
  end

  test "can move waitlisted participant to campsite over capacity" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    campsite.participant_capacity.times do |index|
      create_campsite_signup!(
        campsite: campsite,
        user: User.create!(
          first_name: "Full",
          last_name: "Participant#{index}",
          email: "full-participant-#{index}@example.com",
          password: "password"
        )
      )
    end
    participant = User.create!(
      first_name: "Morgan",
      last_name: "Waitlist",
      email: "morgan-waitlist@example.com",
      password: "password"
    )
    signup = create_waitlisted_signup!(trip: trip, user: participant, waitlist_eligible_at: Time.current)

    patch move_to_campsite_admin_trip_campsite_signup_url(trip, signup), params: {
      campsite_signup: {
        campsite_id: campsite.id
      }
    }

    assert_redirected_to admin_trip_url(trip)
    assert_equal "Morgan Waitlist was moved to Upper Pines site A12.", flash[:notice]
    signup.reload
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_equal "Not chosen yet", signup.attendance_date_range
    assert_not signup.waitlist_eligible?
    assert campsite.reload.signups_locked?
    assert_equal campsite.participant_capacity + 1, campsite.confirmed_signup_count
  end

  test "moving waitlisted participant to campsite moves linked guests" do
    trip = trips(:yosemite)
    campsite = campsites(:yosemite_a)
    primary = User.create!(
      first_name: "Morgan",
      last_name: "Waitlist",
      email: "morgan-linked-waitlist@example.com",
      password: "password"
    )
    guest = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "gina-linked-waitlist@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    signup = create_waitlisted_signup!(trip: trip, user: primary)
    guest_signup = create_waitlisted_signup!(trip: trip, user: guest, guest_of_signup: signup, guest_position: 1)

    patch move_to_campsite_admin_trip_campsite_signup_url(trip, signup), params: {
      campsite_signup: {
        campsite_id: campsite.id
      }
    }

    assert_redirected_to admin_trip_url(trip)
    signup.reload
    guest_signup.reload
    assert signup.confirmed?
    assert guest_signup.confirmed?
    assert_equal campsite, guest_signup.campsite
    assert_nil guest_signup.arrival_date
    assert_nil guest_signup.checkout_date
    assert guest_signup.user.default_password?
  end

  test "does not move confirmed participant to campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    patch move_to_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
      campsite_signup: {
        campsite_id: campsites(:yosemite_b).id
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is already confirmed for this trip.", flash[:alert]
    assert_equal campsites(:yosemite_a), signup.reload.campsite
  end

  test "can move confirmed participant to waitlist" do
    campsite = campsites(:yosemite_a)
    campsite.update!(participant_capacity: 1)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), waitlist_eligible_at: Time.current)

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee was moved to the waitlist.", flash[:notice]
    signup.reload
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waitlist_eligible?
    assert campsite.reload.signups_locked?
  end

  test "moving confirmed primary participant to waitlist moves linked guests" do
    campsite = campsites(:yosemite_a)
    primary_signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "gina-confirmed-move@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsite,
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), primary_signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert primary_signup.reload.waitlisted?
    assert guest_signup.reload.waitlisted?
    assert_nil guest_signup.campsite
    assert_nil guest_signup.arrival_date
    assert_nil guest_signup.checkout_date
  end

  test "does not move waitlisted participant to waitlist" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is already on the waitlist.", flash[:alert]
    assert signup.reload.waitlisted?
  end

  test "can remove confirmed participant from campsite and advance waitlist" do
    campsite = campsites(:yosemite_a)
    campsite.update!(participant_capacity: 1)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    waitlisted_user = User.create!(
      first_name: "Waiting",
      last_name: "Participant",
      email: "waiting-participant@example.com",
      password: "password"
    )
    waitlisted_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: waitlisted_user)

    assert_difference "CampsiteSignup.count", -1 do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee was removed from Upper Pines site A12.", flash[:notice]
    assert campsite.reload.signups_locked?
    assert waitlisted_signup.reload.waitlist_eligible?
  end

  test "does not remove waitlisted participant from campsite" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee is not confirmed for a campsite.", flash[:alert]
    assert signup.reload.waitlisted?
  end

  test "can remove waitlisted participant from waitlist" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))

    assert_difference "CampsiteSignup.count", -1 do
      delete remove_from_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Off belay! Sam Lee was removed from the waitlist.", flash[:notice]
    assert_nil CampsiteSignup.find_by(id: signup.id)
  end

  test "removing waitlisted participant removes linked guests" do
    primary = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "gina-waitlist-remove@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: guest_user,
      guest_of_signup: primary,
      guest_position: 1
    )

    assert_difference "CampsiteSignup.count", -2 do
      delete remove_from_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), primary)
    end

    assert_nil CampsiteSignup.find_by(id: primary.id)
    assert_nil CampsiteSignup.find_by(id: guest_signup.id)
  end

  test "removing eligible waitlisted participant advances next eligible signup" do
    first_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    waiting_user = User.create!(
      first_name: "Next",
      last_name: "Climber",
      email: "next-climber@example.com",
      password: "password"
    )
    next_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: waiting_user)

    delete remove_from_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), first_signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert next_signup.reload.waitlist_eligible?
  end

  test "does not remove confirmed participant from waitlist" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Wow, that was a whipper. Sam Lee is not on the waitlist.", flash[:alert]
    assert signup.reload.confirmed?
  end

  test "admin can mark no payment needed with required reason" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_difference "CampsiteSignupPayment.count", 1 do
      patch mark_no_payment_needed_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          waived_reason: "Scholarship comp"
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    payment = signup.reload.current_payment
    assert payment.waived?
    assert_equal "Scholarship comp", payment.waived_reason
  end

  test "admin can mark participant already paid" do
    SiteSetting.current.update!(first_two_nights_fee: "35", extra_night_fee: "5")
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_difference "CampsiteSignupPayment.count", 1 do
      patch mark_already_paid_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          manual_payment_method: "venmo",
          manual_paid_at: "2026-06-01T12:30",
          note: "Paid David"
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    payment = signup.reload.current_payment
    assert payment.manual_source?
    assert payment.paid?
    assert_equal 4000, payment.amount_cents
    assert_equal "venmo", payment.manual_payment_method
  end

  test "admin can create Stripe payment link after details are complete" do
    SiteSetting.current.update!(first_two_nights_fee: "35")
    signup = attach_test_waiver_to(create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam)))

    with_fake_stripe_checkout do
      assert_difference "CampsiteSignupPayment.count", 1 do
        patch create_payment_link_admin_trip_campsite_signup_url(trips(:yosemite), signup)
      end
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    payment = signup.reload.current_payment
    assert payment.pending?
    assert_equal "https://checkout.stripe.com/c/pay/admin-#{payment.id}", payment.checkout_url
  end

  test "removing paid participant cancels record without refund by default" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.payments.create!(source: "manual", status: "paid", amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup)
    end

    assert signup.reload.canceled?
    assert signup.current_payment.paid?
    assert_equal 0, signup.current_payment.refunded_amount_cents
  end

  test "admin can choose to refund when removing paid participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.payments.create!(source: "manual", status: "paid", amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          issue_refund: "1"
        }
      }
    end

    assert signup.reload.canceled?
    assert signup.current_payment.refunded?
  end

  test "admin stripe refund records admin initiator when removing paid participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_admin_remove"
    )
    stripe_refund = Struct.new(:id, :status).new("re_admin_remove", "succeeded")

    with_fake_stripe_refund(stripe_refund) do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          issue_refund: "1"
        }
      }
    end

    refund = payment.refunds.reload.sole
    assert refund.admin_initiated_by?
    assert_equal users(:alex), refund.refunded_by
    assert_equal "automatic", refund.refund_type
    assert_equal "re_admin_remove", refund.stripe_refund_id
  end

  test "moving paid participant to waitlist does not refund by default" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 1000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )

    patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup)

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert signup.reload.waitlisted?
    assert_equal 0, payment.reload.refunded_amount_cents
    assert payment.paid?
  end

  test "admin stripe refund records admin initiator when moving to waitlist with refund" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 1000,
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_admin_waitlist"
    )
    stripe_refund = Struct.new(:id, :status).new("re_admin_waitlist", "succeeded")

    with_fake_stripe_refund(stripe_refund) do
      patch move_to_waitlist_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          issue_refund: "1"
        }
      }
    end

    refund = payment.refunds.reload.sole
    assert refund.admin_initiated_by?
    assert_equal users(:alex), refund.refunded_by
    assert_equal "automatic", refund.refund_type
    assert_equal "re_admin_waitlist", refund.stripe_refund_id
  end

  test "admin can override refund cutoff when removing paid participant" do
    travel_to Date.new(2026, 6, 6) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(source: "manual", status: "paid", amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

      assert_no_difference "CampsiteSignup.count" do
        delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
          payment: {
            issue_refund: "1"
          }
        }
      end

      assert signup.reload.canceled?
      assert signup.current_payment.refunded?
    end
  end

  test "admin can remove paid participant after campsite dates changed outside attendance dates" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
    signup.payments.create!(source: "manual", status: "paid", amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)
    campsite.update_columns(arrival_date: campsite.arrival_date + 1.day, updated_at: Time.current)

    assert_no_difference "CampsiteSignup.count" do
      delete remove_from_campsite_admin_trip_campsite_signup_url(trips(:yosemite), signup), params: {
        payment: {
          issue_refund: "1"
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Sam Lee was removed from Upper Pines site A12.", flash[:notice]
    assert signup.reload.canceled?
    assert signup.current_payment.refunded?
  end

  private

  def with_fake_stripe_checkout
    original_creator = Rails.application.config.x.stripe_checkout_session_creator
    Rails.application.config.x.stripe_checkout_session_creator = FakeStripeCheckoutSessionCreator
    yield
  ensure
    Rails.application.config.x.stripe_checkout_session_creator = original_creator
  end

  def with_fake_stripe_refund(stripe_refund)
    original_create = Stripe::Refund.method(:create)
    Stripe::Refund.define_singleton_method(:create) { |_params| stripe_refund }
    yield
  ensure
    Stripe::Refund.define_singleton_method(:create, original_create)
  end
end
