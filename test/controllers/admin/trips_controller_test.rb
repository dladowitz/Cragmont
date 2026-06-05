require "test_helper"

class Admin::TripsControllerTest < ActionDispatch::IntegrationTest
  test "can view trips index" do
    get admin_trips_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-public-link", "Public View"
    assert_select ".admin-nav a", text: "Trips"
    assert_select ".admin-nav a", text: "Public View", count: 0
    assert_select ".admin-nav form[action='#{session_path}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
      assert_select "button.button.secondary", text: "Logout"
    end
    assert_select "h2", "Trips"
    assert_select ".admin-filter-tabs a[href='#{admin_trips_path}']", text: "Active"
    assert_select ".admin-filter-tabs a[href='#{admin_trips_path(filter: "deleted")}']", text: "Deleted"
    assert_select "th", text: "Participant Capacity"
    assert_select "th", text: "Signed Up"
    assert_select "th", text: "Actions"
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: "Alex Rivera"
    assert_select "td", text: /Not set yet/
    assert_select "td a[href='#{edit_admin_trip_path(trips(:jtree))}']", text: "Update"
    assert_select "td a[href='#{admin_trip_transactions_path(trips(:jtree))}']", text: "Transactions"
  end

  test "can view deleted trips tab" do
    deleted_trip = trips(:jtree)
    deleted_trip.soft_delete!

    get admin_trips_url

    assert_response :success
    assert_select "td", text: /Joshua Tree Winter/, count: 0

    get admin_trips_url(filter: "deleted")

    assert_response :success
    assert_select "h2", "Deleted trips"
    assert_select "td", text: /Joshua Tree Winter/
    assert_select "form[action='#{restore_admin_trip_path(deleted_trip)}'] button", text: "Restore"
    assert_select "td a[href='#{admin_trip_transactions_path(deleted_trip)}']", text: "Transactions"
  end

  test "trip details link to edit form when campsite coordinator is not set" do
    get admin_trip_url(trips(:jtree))

    assert_response :success
    assert_select ".coordinator-summary", text: /Not set yet/
    assert_select ".coordinator-summary a[href='#{edit_admin_trip_path(trips(:jtree))}']", text: "Update"
  end

  test "can view trip details with campsites" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")
    attach_test_waiver_to(signup)
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa-admin@example.com", password: "password")
    waitlisted_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: waitlisted_user)
    waitlisted_guest = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "willa-admin-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_waitlisted_signup!(trip: trips(:yosemite), user: waitlisted_guest, guest_of_signup: waitlisted_signup, guest_position: 1)
    allowed_user = User.create!(first_name: "Zora", last_name: "Allowed", email: "zora-admin@example.com", password: "password")
    allowed_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: allowed_user, waitlist_eligible_at: Time.current)

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-public-link", "Public View"
    assert_select ".trip-summary-header", text: /Yosemite Valley Spring/
    assert_select ".coordinator-summary", text: /Alex Rivera/
    assert_select ".coordinator-summary", text: /alex@example.com/
    assert_select ".coordinator-summary", text: /555-0100/
    assert_select ".description", text: /Notes:/
    assert_select ".stats", text: /Signed up/
    assert_select ".split-signup-stat section:first-child", text: /1/
    assert_select ".split-signup-stat section:last-child", text: /Under #{SiteSetting.current.uncounted_minor_age_limit}/
    assert_select ".availability-stat", text: /Spaces available/
    assert_select ".availability-stat", text: /9/
    assert_select ".stats", text: /Total capacity/
    assert_select ".stats", text: /Campsites/
    assert_select ".stats span", text: "Car capacity", count: 0
    assert_select ".trip-summary-header .actions a.button.secondary", text: "Edit trip"
    assert_select ".trip-summary-header .actions a.button.secondary[href='#{admin_trip_transactions_path(trips(:yosemite))}']", text: "Transactions"
    assert_select ".trip-summary-header .actions .button.danger", text: "Delete trip", count: 0
    assert_select ".campground-group", count: 0
    assert_select ".admin-campsite-card-header h4", text: "Upper Pines site A12"
    assert_select ".admin-campsite-card-header p", text: "Yosemite National Park"
    assert_select ".campsite-registration", text: /Site registered by:\s*Alex Rivera/
    assert_select "#admin-campsite-#{campsites(:yosemite_b).id}" do
      assert_select ".campsite-registration", text: /Site registered by:/
      assert_select ".campsite-registration", text: /Registration #/
      assert_select ".campsite-registration a[href='#{edit_admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_b))}']", text: "Update", count: 2
    end
    assert_select "a.button.secondary", text: "Add campsite"
    assert_select ".table-actions a.button.secondary", text: "Edit Campsite"
    assert_select "dialog.confirmation-modal", text: /This will not remove signed-up participants from the trip\./, count: 0
    assert_select "#admin-campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".table-actions button", text: "Delete", count: 0
      assert_select ".table-actions > [data-controller='modal'] > button", text: "Add Participant"
      assert_select "dialog.admin-add-participant-modal" do
        assert_select "h2", "Add participant"
        assert_select "p", text: /Upper Pines\s*site A12/
        assert_select "form[action='#{admin_trip_campsite_signups_path(trips(:yosemite))}'][method='post']" do
          assert_select "input[type='hidden'][name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_a).id}']"
          assert_select "input[type='radio'][name='campsite_signup[participant_account_status]'][value='existing'][checked]"
          assert_select "label", text: "Participant has an account"
          assert_select "input[type='radio'][name='campsite_signup[participant_account_status]'][value='new']"
          assert_select "label", text: "Participant does not have an account"
          assert_select "select[name='campsite_signup[user_id]'][required]" do
            assert_select "option[value='#{users(:alex).id}']", text: /Alex Rivera/
            assert_select "option[value='#{users(:alex).id}'][disabled]", count: 0
            assert_select "option[value='#{users(:sam).id}'][disabled]", text: /Sam Lee .* already on trip/
          end
          assert_select "section[data-admin-participant-target='newFields'][hidden]" do
            assert_select "h3", "Create an account and add to campsite"
            assert_select "input[type='text'][name='campsite_signup[new_user][first_name]'][required][disabled]"
            assert_select "input[type='text'][name='campsite_signup[new_user][last_name]'][required][disabled]"
            assert_select "input[type='email'][name='campsite_signup[new_user][email]'][required][disabled]"
            assert_select "input[type='tel'][name='campsite_signup[new_user][phone]'][disabled]"
          end
          assert_select "input[type='submit'][value='Add Participant']"
        end
      end
      assert_select "dialog.confirmation-modal", text: /Delete campsite\?/, count: 0
      assert_select "form[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}']", count: 0
    end
    assert_select "#admin-campsite-#{campsites(:yosemite_b).id}" do
      assert_select ".table-actions button", text: "Delete", count: 0
      assert_select ".table-actions > [data-controller='modal'] > button", text: "Add Participant"
      assert_select "dialog.confirmation-modal", text: /Delete campsite\?/, count: 0
      assert_select "form[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_b))}']", count: 0
    end
    assert_select ".campsite-notes", text: /Close to bathrooms/
    assert_select ".confirmed-signups-section" do
      assert_select "h4", "Confirmed participants"
      assert_equal [ "Participant", "Minors", "Dates", "Payment", "Waiver", "Info", "Move to Waitlist", "Remove" ], css_select(".confirmed-signups-section > table th").map { |header| header.text.strip }
      assert_select "td", text: "Sam Lee"
      assert_select "th", text: "Dates"
      assert_select "th", text: "Attendance", count: 0
      assert_select "td", text: "6/13-6/15"
      assert_select "td", text: "Jun 13-Jun 15", count: 0
      assert_select ".missing-value", text: "Missing", count: 0
      assert_select "td", text: "Willa Wait", count: 0
      assert_select ".admin-minor-list .minor-info-control button.info-link-button[data-action='modal#open']", text: "Mika Lee"
      assert_select "dialog.minor-info-modal" do
        assert_select "h2", "Minor information"
        assert_select "dt", "Name"
        assert_select "dd", "Mika Lee"
        assert_select "dt", "Age"
        assert_select "dd", "12"
        assert_select "dt", "Added by"
        assert_select "dd", "Sam Lee"
        assert_select "dt", "Relationship"
        assert_select "dd", "Child"
        assert_select "button[data-action='modal#close']", text: "Close"
      end
      assert_select "th", text: "Info"
      assert_select "th", text: "Email", count: 0
      assert_select "th", text: "Phone", count: 0
      assert_select ".participant-info-control button.info-link-button[data-action='modal#open']", text: "View"
      assert_select "dialog.participant-info-modal" do
        assert_select "h2", "Participant info"
        assert_select "p", "Sam Lee"
        assert_select "dt", "Email"
        assert_select "a[href='mailto:sam@example.com']", text: "sam@example.com"
        assert_select "dt", "Phone"
        assert_select "dd", "555-0101"
        assert_select "dt", "Membership"
        assert_select "dd", "Non-member"
        assert_select "button[data-action='modal#close']", text: "Close"
      end
      assert_select "th", text: "Waiver"
      assert_select "th", text: "Move to Waitlist"
      assert_select "th", text: "Remove"
      assert_select "button", text: "Waitlist"
      assert_select "button", text: "Move to Waitlist", count: 0
      assert_select "button", text: "Remove"
      assert_select "dialog.confirmation-modal", text: /Move Sam Lee to the waitlist\?/
      assert_select "dialog.confirmation-modal", text: /This will remove their campsite assignment and attendance dates\./
      assert_select "dialog.confirmation-modal form[action='#{move_to_waitlist_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']"
      assert_select "dialog.confirmation-modal", text: /Remove Sam Lee from this campsite\?/
      assert_select "dialog.confirmation-modal", text: /This will remove their signup from the trip\./
      assert_select "dialog.confirmation-modal form[action='#{remove_from_campsite_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']"
      assert_select "th", text: "Status", count: 0
      assert_select ".status.confirmed-status", count: 0
    end
    assert_select ".trip-waitlist-section" do
      assert_select "h3", "Trip waitlist"
      assert_select "tbody > tr", count: 2
      assert_select "td", text: /Willa Wait/
      assert_select "td", text: /1 guest: Gina Guest/
      assert_select "td", text: "Zora Allowed"
      assert_select "td", text: "Gina Guest", count: 0
      assert_select "th", text: "Attendance", count: 0
      assert_select "td", text: "Not chosen yet", count: 0
      assert_select "th", text: /Self Signup/
      assert_select "th", text: /Can Signup/, count: 0
      assert_select "th", text: "Allowed to Signup", count: 0
      assert_select ".tooltip-heading.info-tooltip[aria-label='Participants can sign themselves up from the waitlist']", text: /Self Signup/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Participants can sign themselves up from the waitlist']", text: /Participants can sign themselves up from the waitlist/
      assert_select "th", text: /Signup Ability/, count: 0
      assert_select ".tooltip-heading.info-tooltip[aria-label='Enable participant to sign themselves up from the waitlist']", count: 0
      assert_select "th", text: "Eligibility", count: 0
      assert_select "th", text: "Action", count: 0
      assert_select ".admin-member-status", text: "No", count: 2
      assert_select ".admin-member-status", text: "Member", count: 0
      assert_select ".admin-member-status", text: "Non-member", count: 0
      assert_select ".admin-self-signup-cell", count: 2
      assert_select ".admin-self-signup-status", text: "Disabled"
      assert_select ".admin-self-signup-status", text: "Enabled"
      assert_select "button", text: "Enable"
      assert_select "button", text: "Disable"
      assert_select "form[action='#{make_waitlist_eligible_admin_trip_campsite_signup_path(trips(:yosemite), waitlisted_signup)}'] button", text: "Enable"
      assert_select "form[action='#{revoke_waitlist_eligibility_admin_trip_campsite_signup_path(trips(:yosemite), allowed_signup)}'] button", text: "Disable"
      assert_select ".admin-self-signup-control > .admin-self-signup-status:first-child", count: 2
      assert_select ".admin-self-signup-control > form:last-child button.admin-table-action-button", count: 2
      assert_select ".admin-self-signup-control > .admin-self-signup-status.danger-status", text: "Disabled"
      assert_select "button", text: "Allow", count: 0
      assert_select "button", text: "Allow to Signup", count: 0
      assert_select "button[title='Enable participant to sign themselves up from the waitlist']", count: 0
      assert_select "button", text: "Allow Participant to Signup", count: 0
      assert_select "button", text: "Revoke", count: 0
      assert_select "button", text: "Revoke Signup Ability", count: 0
      assert_select "select[name='campsite_signup[campsite_id]']", count: 0
      assert_select "th", text: /Campsite/
      assert_select "th", text: /Add to Campsite/, count: 0
      assert_select ".tooltip-heading.info-tooltip[aria-label='Adds a participant directly to a campsite']", text: /Campsite/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Adds a participant directly to a campsite']", text: /Adds a participant directly to a campsite/
      assert_select "th", text: "Move to Campsite", count: 0
      assert_select "button", text: "Add to Campsite", count: 0
      assert_select ".admin-waitlist-campsite-name", text: "Upper Pines A12", count: 2
      assert_select ".admin-waitlist-campsite-control > button.admin-table-action-button", text: "Add", count: 2
      assert_select ".admin-waitlist-campsite-control > .admin-waitlist-campsite-name:first-child", text: "Upper Pines A12", count: 2
      assert_select ".admin-waitlist-campsite-control > button.admin-table-action-button:nth-child(2)", text: "Add", count: 2
      assert_select "dialog.signup-modal", text: /Add Willa Wait to a campsite/
      assert_select ".admin-campsite-choice-row", text: /Upper Pines site A12/
      assert_select ".admin-campsite-choice-row", text: /Upper Pines site A13/
      assert_select ".admin-campsite-choice-stats", text: /capacity/
      assert_select "form[action='#{move_to_campsite_admin_trip_campsite_signup_path(trips(:yosemite), waitlisted_signup)}']" do
        assert_select "input[name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_a).id}']"
        assert_select "button", text: "Add"
      end
      assert_select "th", text: /Remove/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Removes Participant from Waitlist']", text: /Remove/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Removes Participant from Waitlist']", text: /Removes Participant from Waitlist/
      assert_select "button", text: "Remove", count: 4
      assert_select ".trip-waitlist-section tbody > tr > td > div[data-controller='modal'] > button.admin-table-action-button", text: "Remove", count: 2
      assert_select "dialog.confirmation-modal", text: /Remove Willa Wait from the waitlist\?/
      assert_select "dialog.confirmation-modal", text: /This will remove their signup from the trip\./
      assert_select "dialog.confirmation-modal form[action='#{remove_from_waitlist_admin_trip_campsite_signup_path(trips(:yosemite), waitlisted_signup)}']"
      assert_select "td", text: "Sam Lee", count: 0
      assert_select "th", text: "Status", count: 0
      assert_select ".status.waitlisted-status", count: 0
    end
    assert_select ".waiver-download a.waiver-download-link", text: /\d{2}\/\d{2}\/\d{2}/
    assert_select ".waiver-download a.waiver-download-link[aria-label^='Download waiver signed on']"
    assert_select ".waiver-download a.waiver-download-link svg.waiver-download-icon"
    assert_select ".waiver-download", text: /Download/, count: 0
  end

  test "trip details show missing waiver for legacy signups" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".missing-value", text: "Missing"
  end

  test "trip details remove modal lets admin choose refund" do
    travel_to Date.new(2026, 6, 5) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 4000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )

      get admin_trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.confirmation-modal", text: /Remove Sam Lee from this campsite\?/ do
        assert_select "dt", "Trip starts"
        assert_select "dd", "June 12, 2026"
        assert_select "dt", "Days until trip"
        assert_select "dd", "7"
        assert_select ".admin-refund-choice", text: /Issue a refund\?/, count: 0
        assert_select ".admin-refund-choice-spacer[aria-hidden='true']"
        assert_select ".admin-refund-choice strong", text: "Policy:"
        assert_select ".admin-refund-choice", text: /Policy:\s*Full refund if 7 or more days before start of trip\. Admins can override policy with a good reason\./
        assert_select ".admin-refund-choice", text: /Amount paid:\s*\$40\.00/
        assert_select "form[action='#{remove_from_campsite_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']", count: 2
        assert_select "input[name='payment[issue_refund]'][value='0']"
        assert_select "button.button.danger.secondary", "Remove without refund"
        assert_select "input[name='payment[issue_refund]'][value='1']"
        assert_select "button.button.danger", "Remove and issue refund"
      end
    end
  end

  test "trip details remove modal emphasizes no refund inside cutoff" do
    travel_to Date.new(2026, 6, 6) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 4000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )

      get admin_trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.confirmation-modal", text: /Remove Sam Lee from this campsite\?/ do
        assert_select "dd", "6"
        assert_select "form[action='#{remove_from_campsite_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']", count: 2
        assert_select "input[name='payment[issue_refund]'][value='0']"
        assert_select "button.button.danger", "Remove without refund"
        assert_select "input[name='payment[issue_refund]'][value='1']"
        assert_select "button.button.danger.secondary", "Remove and issue refund"
      end
    end
  end

  test "trip details waitlist modal lets admin choose refund" do
    travel_to Date.new(2026, 6, 5) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 4000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )

      get admin_trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.confirmation-modal", text: /Move Sam Lee to the waitlist\?/ do
        assert_select "dt", "Trip starts"
        assert_select "dd", "June 12, 2026"
        assert_select "dt", "Days until trip"
        assert_select "dd", "7"
        assert_select ".admin-refund-choice strong", text: "Policy:"
        assert_select ".admin-refund-choice", text: /Policy:\s*Full refund if 7 or more days before start of trip\. Admins can override policy with a good reason\./
        assert_select ".admin-refund-choice", text: /Amount paid:\s*\$40\.00/
        assert_select "form[action='#{move_to_waitlist_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']", count: 2
        assert_select "input[name='payment[issue_refund]'][value='0']"
        assert_select "button.button.danger.secondary", "Move without refund"
        assert_select "input[name='payment[issue_refund]'][value='1']"
        assert_select "button.button.danger", "Move and issue refund"
      end
    end
  end

  test "trip details waitlist modal emphasizes no refund inside cutoff" do
    travel_to Date.new(2026, 6, 6) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 4000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )

      get admin_trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.confirmation-modal", text: /Move Sam Lee to the waitlist\?/ do
        assert_select "dd", "6"
        assert_select "form[action='#{move_to_waitlist_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']", count: 2
        assert_select "input[name='payment[issue_refund]'][value='0']"
        assert_select "button.button.danger", "Move without refund"
        assert_select "input[name='payment[issue_refund]'][value='1']"
        assert_select "button.button.danger.secondary", "Move and issue refund"
      end
    end
  end

  test "trip details shows missing dates for admin-assigned participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.update!(arrival_date: nil, checkout_date: nil)
    attach_test_waiver_to(signup)

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section" do
      assert_select "th", text: "Dates"
      assert_select "td", text: "Not chosen yet", count: 0
      assert_select ".missing-value", text: "Missing"
    end
  end

  test "trip details links missing dates and waiver to participant collection modal" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: nil, checkout_date: nil)
    participant_link = trip_url(
      trips(:yosemite),
      complete_signup: signup.signed_id(purpose: :complete_participant_details),
      anchor: "campsite-#{signup.campsite_id}"
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section" do
      assert_select "button.missing-value.missing-link[data-action='copyable-modal#open']", text: "Missing", count: 2
      assert_select "dialog.missing-details-modal", count: 1
      assert_select "dialog.missing-details-modal", text: /We need to collect waiver and attendance dates from this participant\./
      assert_select "dialog.missing-details-modal", text: /Share this link with the participant so they can sign the waiver and select dates:/
      assert_select "a.missing-details-link[href='#{participant_link}']", text: "Waiver and Date Selection Link"
      assert_select "button.copy-link-button[data-action='copyable-modal#copy']", text: "Copy link"
      assert_select "button.copy-link-button .copy-icon svg"
      assert_select "button.copy-link-button .check-icon svg"
      assert_select "button[data-action='copyable-modal#close']", text: "Close"
    end
  end

  test "trip details links guest missing waiver to guest password and waiver collection modal" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "admin-guest-link@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )
    guest_link = trip_url(
      trips(:yosemite),
      complete_signup: guest_signup.signed_id(purpose: :complete_guest_details),
      anchor: "campsite-#{guest_signup.campsite_id}"
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section" do
      assert_select "td", text: /Gina Guest/
      assert_select "td", text: /Added by Sam Lee/
      assert_select "button.missing-value.missing-link[data-action='copyable-modal#open']", text: "Missing"
      assert_select "dialog.missing-details-modal", text: /We need to collect a waiver from this guest\./
      assert_select "dialog.missing-details-modal", text: /Share this link with the guest so they can sign the waiver:/
      assert_select "a.missing-details-link[href='#{guest_link}']", text: "Waiver Link"
      assert_select "td", text: "Follows primary"
    end
  end

  test "trip details shows guest paid by primary participant" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    primary_signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 8000,
      manual_payment_method: "venmo",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "admin-guest-paid-by-primary@example.com",
      password: User::DEFAULT_GUEST_PASSWORD
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section tbody tr", text: /Sam Lee/ do
      assert_select ".admin-payment-status", text: "Paid"
      assert_select ".admin-payment-amount", text: "$80.00"
    end
    assert_select ".confirmed-signups-section tbody tr", text: /Gina Guest/ do
      assert_select ".admin-payment-status", text: "Paid"
      assert_select ".admin-payment-covered-by", text: "Paid by Sam Lee"
      assert_select ".admin-payment-amount", count: 0
      assert_select ".admin-payment-control button", text: "Update", count: 0
    end
  end

  test "trip details with no campsites show one add campsite link" do
    trip = Trip.create!(
      name: "Empty Trip",
      location: "Somewhere",
      start_date: "2026-09-01",
      end_date: "2026-09-03"
    )

    get admin_trip_url(trip)

    assert_response :success
    assert_select ".empty-state", text: /No campsites have been added to this trip yet/
    assert_select "a[href='#{new_admin_trip_campsite_path(trip)}']", text: "Add campsite", count: 1
  end

  test "can create trip" do
    assert_difference "Trip.count", 1 do
      post admin_trips_url, params: {
        trip: {
          name: "Smith Rock Summer",
          location: "Terrebonne, OR",
          start_date: "2026-08-01",
          end_date: "2026-08-04",
          description: "Tuff and sport climbing.",
          status: "draft"
        }
      }
    end

    assert_redirected_to admin_trip_url(Trip.order(:created_at).last)
  end

  test "can render new trip form" do
    get new_admin_trip_url

    assert_response :success
  end

  test "can update trip" do
    patch admin_trip_url(trips(:jtree)), params: {
      trip: {
        name: "Joshua Tree Winter Session",
        location: trips(:jtree).location,
        start_date: trips(:jtree).start_date,
        end_date: trips(:jtree).end_date,
        description: trips(:jtree).description,
        status: "published",
        campsite_coordinator_id: users(:sam).id
      }
    }

    assert_redirected_to admin_trip_url(trips(:jtree))
    assert_equal "Joshua Tree Winter Session", trips(:jtree).reload.name
    assert trips(:jtree).published?
    assert_equal users(:sam), trips(:jtree).campsite_coordinator
  end

  test "can publish trip before campsite coordinator is known" do
    patch admin_trip_url(trips(:jtree)), params: {
      trip: {
        name: trips(:jtree).name,
        location: trips(:jtree).location,
        start_date: trips(:jtree).start_date,
        end_date: trips(:jtree).end_date,
        description: trips(:jtree).description,
        status: "published",
        campsite_coordinator_id: ""
      }
    }

    assert_redirected_to admin_trip_url(trips(:jtree))
    assert trips(:jtree).reload.published?
    assert_nil trips(:jtree).campsite_coordinator
  end

  test "can render edit trip form" do
    trip = trips(:jtree)

    get edit_admin_trip_url(trip)

    assert_response :success
    assert_select ".danger-form-action [data-controller='modal'] > button.button.danger.secondary", text: "Delete trip"
    assert_select "dialog.confirmation-modal", text: /Delete trip\?/
    assert_select "dialog.confirmation-modal", text: /transaction history will be preserved/
    assert_select "button[form='delete-trip-#{trip.id}']", text: "Delete trip"
    assert_select "form#delete-trip-#{trip.id}[action='#{admin_trip_path(trip)}']"
  end

  test "edit trip blocks deleting a trip with participants signed up" do
    trip = trips(:yosemite)
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    get edit_admin_trip_url(trip)

    assert_response :success
    assert_select ".danger-form-action .disabled-modal-trigger[aria-disabled='true'][role='button']", text: "Delete trip"
    assert_select ".danger-form-action .disabled-modal-trigger button.button.danger.secondary[disabled]", text: "Delete trip"
    assert_select "dialog.confirmation-modal", text: /Cannot delete a trip with participants signed up/
    assert_select "button[form='delete-trip-#{trip.id}']", count: 0
    assert_select "form#delete-trip-#{trip.id}", count: 0
  end

  test "edit trip allows delete when only canceled payment history remains" do
    trip = Trip.create!(
      name: "Empty History Trip",
      location: "Joshua Tree, CA",
      start_date: Date.new(2026, 12, 10),
      end_date: Date.new(2026, 12, 12),
      status: "draft"
    )
    signup = CampsiteSignup.create!(trip: trip, user: users(:sam), status: "canceled")
    signup.payments.create!(source: "manual", status: "refunded", amount_cents: 1000, refunded_amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    get edit_admin_trip_url(trip)

    assert_response :success
    assert_select ".danger-form-action [data-controller='modal'] > button.button.danger.secondary", text: "Delete trip"
    assert_select "dialog.confirmation-modal", text: /Delete trip\?/
    assert_select "button[form='delete-trip-#{trip.id}']", text: "Delete trip"
    assert_select "dialog.confirmation-modal", text: /Cannot delete a trip with participants signed up/, count: 0
  end

  test "can delete trip" do
    trip = trips(:jtree)

    assert_no_difference "Trip.count" do
      delete admin_trip_url(trip)
    end

    assert_redirected_to admin_trips_url
    assert trip.reload.deleted?
    assert_equal "Trip was deleted. Transaction history is still on belay.", flash[:notice]
  end

  test "delete trip preserves canceled payment history" do
    trip = Trip.create!(
      name: "Canceled History Trip",
      location: "Yosemite Valley, CA",
      start_date: Date.new(2026, 7, 10),
      end_date: Date.new(2026, 7, 12),
      status: "draft"
    )
    signup = CampsiteSignup.create!(trip: trip, user: users(:sam), status: "canceled")
    payment = signup.payments.create!(source: "manual", status: "refunded", amount_cents: 1000, refunded_amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    assert_no_difference "Trip.count" do
      assert_no_difference "CampsiteSignup.count" do
        assert_no_difference "CampsiteSignupPayment.count" do
          delete admin_trip_url(trip)
        end
      end
    end

    assert_redirected_to admin_trips_url
    assert trip.reload.deleted?
    assert CampsiteSignup.exists?(signup.id)
    assert CampsiteSignupPayment.exists?(payment.id)
  end

  test "can restore deleted trip" do
    trip = trips(:jtree)
    trip.soft_delete!

    patch restore_admin_trip_url(trip)

    assert_redirected_to admin_trip_url(trip)
    assert_not trip.reload.deleted?
    assert_equal "On belay! Trip was restored.", flash[:notice]
  end

  test "deleted trip page is read only except transactions and restore" do
    trip = trips(:yosemite)
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    trip.update_columns(deleted_at: Time.current)

    get admin_trip_url(trip)

    assert_response :success
    assert_select ".deleted-trip-banner", text: /This trip has been deleted/
    assert_select "a[href='#{admin_trip_transactions_path(trip)}']", text: "Transactions"
    assert_select "form[action='#{restore_admin_trip_path(trip)}'] button", text: "Restore trip"
    assert_select "a[href='#{edit_admin_trip_path(trip)}']", count: 0
    assert_select "a[href='#{new_admin_trip_campsite_path(trip)}']", count: 0
    assert_select "button", text: "Add Participant", count: 0
    assert_select "button", text: "Waitlist", count: 0
    assert_select "button", text: "Remove", count: 0
    assert_select "button", text: "Update", count: 0
  end

  test "deleted trip cannot be edited until restored" do
    trip = trips(:jtree)
    trip.soft_delete!

    get edit_admin_trip_url(trip)

    assert_redirected_to admin_trip_url(trip)
    assert_equal "Restore this trip before making changes.", flash[:alert]
  end

  test "cannot delete trip with participants signed up" do
    trip = trips(:yosemite)
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference "Trip.count" do
      delete admin_trip_url(trip)
    end

    assert_redirected_to edit_admin_trip_url(trip)
    assert_equal "Cannot delete a trip with participants signed up", flash[:alert]
  end
end
