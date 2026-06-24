require "test_helper"

class TripDetailsEmailDeliveryTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    TripDetailsEmailTemplate.ensure_defaults!
    @template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite")
    @trip = trips(:yosemite)
    campsites(:yosemite_b).update!(
      registered_by: users(:sam),
      registration_number: "YO-2026-A13"
    )
  end

  test "sends individual emails to confirmed participants and snapshots what went out" do
    @trip.update!(photo_album_url: "https://photos.google.com/share/yosemite-spring")
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(first_name: "Gina", last_name: "Guest", email: "gina-trip-details@example.com", password: User::DEFAULT_GUEST_PASSWORD, default_password: true)
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )
    waitlisted_user = User.create!(first_name: "Wendy", last_name: "Wait", email: "wendy-trip-details@example.com", password: "password")
    create_waitlisted_signup!(trip: @trip, user: waitlisted_user)
    pending_user = User.create!(first_name: "Parker", last_name: "Pending", email: "parker-trip-details@example.com", password: "password")
    create_campsite_signup!(campsite: campsites(:yosemite_b), user: pending_user, status: "pending_payment")

    email = @template.build_trip_details_email(@trip)
    email.save!

    assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
      TripDetailsEmailDelivery.deliver!(trip_details_email: email, sent_by: users(:alex))
    end

    email.reload
    assert email.sent?
    assert_equal users(:alex), email.sent_by
    assert_not_nil email.sent_at
    assert_equal "Yosemite", email.template_name_snapshot
    assert_includes email.subject, "Upper Pines"
    assert_includes email.body_markdown, "YO-2026-A13"
    assert_includes email.rendered_html_snapshot, "<h2>Campsite Assignments"
    assert_includes email.rendered_html_snapshot, "<h2>Trip Photo Album</h2>"
    assert_includes email.rendered_html_snapshot, "https://photos.google.com/share/yosemite-spring"
    assert_not_includes email.rendered_text_snapshot, "{{campsite_registration_info}}"
    assert_not_includes email.rendered_text_snapshot, "{{photo_album_url}}"

    assert_equal [ "Gina Guest", "Sam Lee" ], email.trip_details_email_recipients.order(:recipient_name).pluck(:recipient_name)
    assert_equal 2, email.trip_details_email_recipients.delivered.count
    assert_equal [ [ users(:sam).email ], [ guest_user.email ] ].sort, ActionMailer::Base.deliveries.map(&:to).sort
    assert ActionMailer::Base.deliveries.all? { |mail| mail.bcc.blank? }
  end

  test "blocks delivery when required campsite registration details are missing" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    campsites(:yosemite_b).update!(registered_by: nil, registration_number: nil)
    email = @template.build_trip_details_email(@trip)
    email.save!

    error = assert_raises TripDetailsEmailDelivery::BlockingIssuesError do
      TripDetailsEmailDelivery.deliver!(trip_details_email: email, sent_by: users(:alex))
    end

    assert_includes error.issues.join(" "), "Upper Pines site A13"
    assert email.reload.draft?
    assert_empty ActionMailer::Base.deliveries
  end

  test "sent emails cannot be edited or sent again" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    email = @template.build_trip_details_email(@trip)
    email.save!
    TripDetailsEmailDelivery.deliver!(trip_details_email: email, sent_by: users(:alex))

    email.subject = "Changed subject"

    assert_not email.valid?
    assert_includes email.errors[:base], "Sent trip details emails cannot be changed"
    assert_raises TripDetailsEmailDelivery::AlreadySentError do
      TripDetailsEmailDelivery.deliver!(trip_details_email: email.reload, sent_by: users(:alex))
    end
  end
end
