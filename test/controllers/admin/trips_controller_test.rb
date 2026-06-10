require "test_helper"

class Admin::TripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

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
    assert_select ".admin-filter-tabs", count: 0
    assert_select "form.trip-filter-form[action='#{admin_trips_path}'][method='get']"
    assert_select "input[name='filters'][value='1']"
    assert_select "input#trip_status_draft[checked]"
    assert_select "input#trip_status_published[checked]"
    assert_select "input#trip_status_archived[checked]"
    assert_select "input#trip_status_deleted[checked]", count: 0
    assert_select ".trip-status-filter", text: "Draft"
    assert_select ".trip-status-filter", text: "Published"
    assert_select ".trip-status-filter", text: "Archived"
    assert_select ".trip-status-filter", text: "Deleted"
    assert_select "th", text: "Participant Capacity"
    assert_select "th", text: "Signed Up"
    assert_select "th", text: "Actions"
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: "Alex Rivera"
    assert_select "td", text: /Not set yet/
    assert_select "td a[href='#{edit_admin_trip_path(trips(:jtree))}']", text: "Update"
    assert_select "td a[href='#{admin_trip_transactions_path(trips(:jtree))}']", text: "Transactions"
  end

  test "assigned campsite coordinator sees only assigned trips and can edit trip details" do
    coordinator = users(:sam)
    trips(:jtree).update!(campsite_coordinator: coordinator)
    delete session_url
    log_in_as(coordinator)

    get admin_trips_url

    assert_response :success
    assert_select "td", text: /Joshua Tree Winter/
    assert_select "td", text: /Yosemite Valley Spring/, count: 0
    assert_select ".admin-nav a", text: "Campgrounds", count: 0
    assert_select ".admin-nav a", text: "Users", count: 0
    assert_select ".admin-nav a", text: "Settings", count: 0

    get edit_admin_trip_url(trips(:jtree))

    assert_response :success
    assert_select "input[name='trip[name]']"
    assert_select "select[name='trip[campsite_coordinator_id]']", count: 0
    assert_select ".coordinator-picker", count: 0

    patch admin_trip_url(trips(:jtree)), params: {
      trip: {
        name: "Joshua Tree Coordinator Edit",
        location: trips(:jtree).location,
        start_date: trips(:jtree).start_date,
        end_date: trips(:jtree).end_date,
        status: trips(:jtree).status,
        campsite_coordinator_id: users(:alex).id
      }
    }

    assert_redirected_to admin_trip_url(trips(:jtree))
    assert_equal "Joshua Tree Coordinator Edit", trips(:jtree).reload.name
    assert_equal coordinator, trips(:jtree).campsite_coordinator
  end

  test "assigned campsite coordinator cannot edit unassigned trip" do
    coordinator = users(:sam)
    trips(:jtree).update!(campsite_coordinator: coordinator)
    delete session_url
    log_in_as(coordinator)

    get edit_admin_trip_url(trips(:yosemite))

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. You do not have permission to access that page.", flash[:alert]
  end

  test "finance admin can view trip payment surfaces but not edit trip setup" do
    finance_user = users(:sam)
    assign_role(finance_user, :finance_admin)
    delete session_url
    log_in_as(finance_user)

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-summary-header .actions a[href='#{admin_trip_transactions_path(trips(:yosemite))}']", text: "Transactions"
    assert_select "a", text: "Edit trip", count: 0
    assert_select "a.button.secondary", text: "Add campsite", count: 0
    assert_select ".table-actions > [data-controller='modal'] > button", text: "Add Participant", count: 0
    assert_select "#trip-payment-requests"

    get edit_admin_trip_url(trips(:yosemite))

    assert_redirected_to root_url
  end

  test "trip admin can manage campgrounds but not users or settings" do
    trip_admin = users(:sam)
    assign_role(trip_admin, :trip_admin)
    delete session_url
    log_in_as(trip_admin)

    get admin_campgrounds_url
    assert_response :success

    get admin_users_url
    assert_redirected_to root_url

    get admin_settings_url
    assert_redirected_to root_url
  end

  test "can filter trips by status and deleted state" do
    deleted_trip = trips(:jtree)
    deleted_trip.soft_delete!
    trips(:yosemite).update!(status: "archived")

    get admin_trips_url

    assert_response :success
    assert_select "td", text: /Joshua Tree Winter/, count: 0
    assert_select "td", text: /Yosemite Valley Spring/

    get admin_trips_url, params: { filters: "1", status: [ "deleted" ] }

    assert_response :success
    assert_select "h2", "Trips"
    assert_select "input#trip_status_draft[checked]", count: 0
    assert_select "input#trip_status_published[checked]", count: 0
    assert_select "input#trip_status_archived[checked]", count: 0
    assert_select "input#trip_status_deleted[checked]"
    assert_select "td", text: /Joshua Tree Winter/
    assert_select ".deleted-status", text: "Deleted"
    assert_select "td", text: /Yosemite Valley Spring/, count: 0
    assert_select "form[action='#{restore_admin_trip_path(deleted_trip)}'] button", text: "Restore"
    assert_select "td a[href='#{admin_trip_transactions_path(deleted_trip)}']", text: "Transactions"

    get admin_trips_url, params: { filters: "1", status: [ "archived" ] }

    assert_response :success
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: /Joshua Tree Winter/, count: 0
    assert_select ".archived-status", text: "Archived"
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
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 3000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
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
    assert_select ".split-signup-stat section:last-child .under-minor-tooltip" do
      assert_select ".info-tooltip-icon", text: "i"
      assert_select ".info-tooltip-box", text: "Children under 10 don't count against Total Capacity"
    end
    assert_select ".availability-stat", text: /Open Spaces/
    assert_select ".availability-stat", text: /9/
    assert_select ".stats", text: /Total Capacity/
    assert_select ".stats", text: /Campsites/
    assert_select ".stats span", text: "Car capacity", count: 0
    assert_select "#admin-campsite-#{campsites(:yosemite_a).id} .parking-stat" do
      assert_select "> span", text: "Parking"
      assert_select "> .parking-tooltip", count: 0
      assert_select ".parking-breakdown-item", text: /Reserved/
      assert_select ".parking-breakdown-item", text: /Open/
    end
    assert_select "#admin-campsite-#{campsites(:yosemite_a).id} .campsite-stats .split-signup-stat" do
      assert_select "section:first-child", text: /1/
      assert_select "section:first-child", text: /Signed up/
      assert_select "section:last-child", text: /1/
      assert_select "section:last-child", text: /Under #{SiteSetting.current.uncounted_minor_age_limit}/
      assert_select "section:last-child .under-minor-tooltip" do
        assert_select ".info-tooltip-icon", text: "i"
        assert_select ".info-tooltip-box", text: "Children under 10 don't count against Total Capacity"
      end
    end
    assert_select "#admin-campsite-#{campsites(:yosemite_a).id} .campsite-stats", text: /Cars/, count: 0
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
          assert_select ".participant-picker[data-controller='participant-picker']"
          assert_select "input[type='hidden'][name='campsite_signup[user_id]'][data-admin-participant-target='existingInput'][data-participant-picker-target='input']"
          assert_select "button.participant-picker-button[role='combobox']", text: "Choose a participant"
          assert_select "input.participant-picker-search[placeholder='Search by name or email']"
          assert_select "button.participant-picker-option[data-value='#{users(:alex).id}']", text: /Alex Rivera/
          assert_select "button.participant-picker-option[data-value='#{users(:alex).id}'][disabled]", count: 0
          assert_select "button.participant-picker-option[data-value='#{users(:sam).id}'][disabled]", text: /Sam Lee .* already on trip/
          assert_select "section[data-admin-participant-target='newFields'][hidden]" do
            assert_select "h3", "Create an account and add to campsite"
            assert_select "input[type='text'][name='campsite_signup[new_user][first_name]'][required][disabled]"
            assert_select "input[type='text'][name='campsite_signup[new_user][last_name]'][required][disabled]"
            assert_select "input[type='email'][name='campsite_signup[new_user][email]'][required][disabled]"
            assert_select "input[type='tel'][name='campsite_signup[new_user][phone]'][disabled]"
          end
          assert_select "legend", text: "Waive Payment"
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='0'][checked]"
          assert_select "label", text: "No"
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='1']"
          assert_select "label", text: "Yes"
          assert_select "section[data-admin-participant-target='waiveReasonFields'][hidden]" do
            assert_select "select[name='campsite_signup[waived_reason_type]'][disabled]" do
              assert_select "option", text: "Campsite Coordinator"
              assert_select "option", text: "Other"
            end
            assert_select "[data-admin-participant-target='otherWaiveReasonField'][hidden]" do
              assert_select "textarea[name='campsite_signup[waived_reason]'][disabled]"
            end
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
      assert_equal [ "Participant", "Dates", "Parking", "Payment", "Waiver", "Info", "Minors", "Reservation" ], css_select(".confirmed-signups-section > table > thead > tr > th").map { |header| header.at_css(".tooltip-heading > span:first-child")&.text&.strip || header.text.strip }
      assert_select "td", text: "Sam Lee"
      assert_select "th", text: "Dates"
      assert_select "th .parking-tooltip" do
        assert_select ".info-tooltip-icon", text: "i"
        assert_select ".info-tooltip-box", text: /Reserved Spots are assigned to the person who registered the site/
        assert_select ".info-tooltip-box", text: /Other spots are set to Open and are first come, first serve/
      end
      assert_select "th", text: "Attendance", count: 0
      assert_select "td", text: "6/13-6/15"
      assert_select "form[action='#{update_parking_status_admin_trip_campsite_signup_path(trips(:yosemite), signup)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "select[name='campsite_signup[parking_status]']" do
          assert_select "option[value='unassigned'][selected]", text: "Unassigned"
          assert_select "option[value='reserved_spot']", text: "Reserved Spot"
          assert_select "option[value='first_come_first_serve']", text: "Open Spot"
          assert_select "option[value='overflow_parking']", text: "Overflow Lot"
          assert_select "option[value='day_use']", text: "Day Use"
        end
      end
      assert_select "td", text: "Jun 13-Jun 15", count: 0
      assert_select ".missing-value", text: "Missing", count: 0
      assert_select "td", text: "Willa Wait", count: 0
      assert_select ".admin-minor-list .minor-info-control button.info-link-button[data-action='modal#open']", text: "Mika L."
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
      assert_select "th", text: "Reservation"
      assert_select "th", text: "Move to Waitlist", count: 0
      assert_select "th", text: "Remove", count: 0
      assert_select "button", text: "Change"
      assert_select "button", text: "Move to a Different Campsite"
      assert_select "button", text: "Move to Waitlist"
      assert_select "button", text: "Remove Reservation"
      assert_select "button", text: "Waitlist", count: 0
      assert_select "button.admin-confirmed-signup-action-button", text: "Change"
      assert_select "button.admin-confirmed-signup-action-button", text: "Move Site", count: 0
      assert_select "button.admin-confirmed-signup-action-button", text: "Waitlist", count: 0
      assert_select "button.admin-confirmed-signup-action-button", text: "Remove", count: 0
      assert_select "dialog.signup-modal", text: /Change Sam Lee's reservation/ do
        assert_select "button", text: "Move to a Different Campsite"
        assert_select "button", text: "Move to Waitlist"
        assert_select "button", text: "Remove Reservation"
      end
      assert_select "dialog.signup-modal", text: /Move Sam Lee to another campsite/ do
        assert_select "p", text: /This keeps their dates, waiver, and payment status unchanged/
        assert_select "form[action='#{move_to_campsite_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']" do
          assert_select "input[type='radio'][name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_b).id}'][checked]"
          assert_select ".admin-campsite-choice-copy", text: /Upper Pines\s+site A13/
          assert_select ".admin-campsite-choice-stats", text: /capacity/
          assert_select "input[type='submit'][value='Move Site']"
        end
      end
      assert_select "dialog.confirmation-modal", text: /Move Sam Lee to the waitlist\?/
      assert_select "dialog.confirmation-modal", text: /This will remove their campsite assignment and attendance dates\./
      assert_select "dialog.confirmation-modal form[action='#{move_to_waitlist_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']"
      assert_select "dialog.confirmation-modal", text: /Remove Sam Lee from this campsite\?/
      assert_select "dialog.confirmation-modal", text: /This will remove their signup from the trip\./
      assert_select "dialog.confirmation-modal form[action='#{remove_from_campsite_admin_trip_campsite_signup_path(trips(:yosemite), signup)}']"
      assert_select "th", text: "Status", count: 0
      assert_select ".status.confirmed-status", count: 0
    end
    assert_select "#admin-campsite-#{campsites(:yosemite_a).id} .parking-status-groups", count: 0
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
        assert_select ".admin-waitlist-campsite-choice-row", count: 2
        assert_select ".admin-waitlist-campsite-choice-row.is-selected", count: 1
        assert_select "input[type='radio'][name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_a).id}'][checked]"
        assert_select "input[type='radio'][name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_b).id}']"
        assert_select "legend", text: "Waive Payment?", count: 2
        assert_select ".admin-waitlist-campsite-choice-row.is-selected" do
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='0'][checked]"
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='0'][disabled]", count: 0
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='1']"
          assert_select "input[type='radio'][name='campsite_signup[waive_payment]'][value='1'][disabled]", count: 0
        end
        assert_select ".admin-waitlist-campsite-choice-row:not(.is-selected) input[type='radio'][name='campsite_signup[waive_payment]'][disabled]", count: 2
        assert_select "select[name='campsite_signup[waived_reason_type]'][disabled]", count: 2
        assert_select "select[name='campsite_signup[waived_reason_type]'][disabled]" do
          assert_select "option[value='campsite_coordinator']", text: "Campsite Coordinator"
          assert_select "option[value='other']", text: "Other"
        end
        assert_select "textarea[name='campsite_signup[waived_reason]'][disabled]", count: 2
        assert_select "input[type='submit'][value='Add']"
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
    assert_select "a.waiver-check-link[href='#{admin_user_path(users(:sam))}']"
    assert_select "a.waiver-check-link svg.waiver-check-icon"
    assert_select ".waiver-download", count: 0
  end

  test "confirmed participant reservation actions hide move site when trip has one campsite" do
    trip = trips(:jtree)
    create_campsite_signup!(campsite: campsites(:jtree_a), user: users(:sam))

    get admin_trip_url(trip)

    assert_response :success
    assert_select ".confirmed-signups-section" do
      assert_select "th", text: "Reservation"
      assert_select "button.admin-confirmed-signup-action-button", text: "Change"
      assert_select "dialog.signup-modal", text: /Change Sam Lee's reservation/ do
        assert_select "button", text: "Move to a Different Campsite", count: 0
        assert_select "button", text: "Move to Waitlist"
        assert_select "button", text: "Remove Reservation"
      end
    end
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

  test "trip details remove modal shows guest paid share from primary participant" do
    travel_to Date.new(2026, 6, 5) do
      SiteSetting.current.update!(first_two_nights_fee: "30", extra_night_fee: "0")
      tiger = User.create!(first_name: "Tiger", last_name: "Ladowitz", email: "tiger-guest-payer@example.com", password: "password")
      david = User.create!(first_name: "David", last_name: "Ladowitz", email: "david-guest-paid@example.com", password: "password")
      primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: tiger)
      guest_signup = create_campsite_signup!(
        campsite: campsites(:yosemite_a),
        user: david,
        guest_of_signup: primary_signup,
        guest_position: 1,
        arrival_date: primary_signup.arrival_date,
        checkout_date: primary_signup.checkout_date
      )
      pricing = CampsiteSignupPricing.call(
        arrival_date: primary_signup.arrival_date,
        checkout_date: primary_signup.checkout_date,
        adult_guest_count: 1
      )
      primary_signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: pricing.amount_cents,
        pricing_snapshot: pricing.snapshot,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )

      get admin_trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.confirmation-modal", text: /Remove David Ladowitz from this campsite\?/ do
        assert_select ".admin-refund-choice", text: /Tiger Ladowitz paid for David Ladowitz:\s*\$30\.00/
        assert_select ".admin-refund-choice", text: /Amount paid:\s*\$60\.00/, count: 0
        assert_select "form[action='#{remove_from_campsite_admin_trip_campsite_signup_path(trips(:yosemite), guest_signup)}']", count: 2
        assert_select "button.button.danger.secondary", "Remove without refund"
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
      assert_select "button.missing-value.missing-link[data-action='copyable-modal#open']", text: "Missing", count: 3
      assert_select "dialog.missing-details-modal", count: 1
      assert_select "dialog.missing-details-modal", text: /We need to collect waiver, attendance dates, and payment from this participant\./
      assert_select "dialog.missing-details-modal", text: /Share this link with the participant so they can sign the waiver, select dates, and pay for the trip:/
      assert_select "a.missing-details-link[href='#{participant_link}']", text: "Date selection, waiver, and payment link"
      assert_select "button.copy-link-button[data-action='copyable-modal#copy']", text: "Copy Link"
      assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", email_participant_link_admin_trip_campsite_signup_path(trips(:yosemite), signup), text: "Email link to participant"
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
      assert_select "td", text: /Added by Sam L\./, count: 0
      assert_select ".admin-party-guest-kicker", count: 0
      assert_select "tr.admin-party-primary-row", text: /Sam Lee/
      assert_select "tr.admin-party-guest-row.admin-party-last-row", text: /Gina Guest/
      assert_select "button.missing-value.missing-link[data-action='copyable-modal#open']", text: "Missing"
      assert_select "dialog.missing-details-modal", text: /We need to collect a waiver from this guest\./
      assert_select "dialog.missing-details-modal", text: /Share this link with the guest so they can sign the waiver:/
      assert_select "a.missing-details-link[href='#{guest_link}']", text: "Waiver Link"
      assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", email_participant_link_admin_trip_campsite_signup_path(trips(:yosemite), guest_signup), text: "Email link to guest"
      assert_select "td", text: "Follows primary", count: 0
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
    rows = css_select(".confirmed-signups-section table").first.css("> tbody > tr")
    sam_row = rows.find { |row| row.css("td").first&.text&.squish&.include?("Sam Lee") }
    gina_row = rows.find { |row| row.css("td").first&.text&.squish&.include?("Gina Guest") }

    assert sam_row
    assert_equal "Paid", sam_row.at_css(".admin-payment-status").text.squish
    assert_equal "$80.00", sam_row.at_css(".admin-payment-amount").text.squish

    assert gina_row
    assert_includes gina_row["class"], "admin-party-guest-row"
    assert_empty gina_row.css(".admin-payment-status")
    assert_empty gina_row.css(".admin-payment-covered-by")
    assert_empty gina_row.css(".admin-payment-amount")
    assert_empty gina_row.css(".admin-payment-control button").select { |button| button.text.squish == "Update" }
  end

  test "trip details shows missing payment link for participant without payment" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    attach_test_waiver_to(signup)
    participant_link = trip_url(
      trips(:yosemite),
      complete_signup: signup.signed_id(purpose: :complete_participant_details),
      anchor: "campsite-#{signup.campsite_id}"
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    rows = css_select(".confirmed-signups-section table").first.css("> tbody > tr")
    sam_row = rows.find { |row| row.css("td").first&.text&.squish&.include?(signup.user.full_name) }

    assert sam_row
    assert_empty sam_row.css(".admin-payment-status")
    assert_equal "Missing", sam_row.at_css(".admin-payment-control button.missing-link").text.squish
    assert_empty sam_row.css(".admin-payment-control button").select { |button| button.text.squish == "Update" }
    assert_no_match(/Unpaid/, sam_row.text)
    assert_no_match(/Payment for #{signup.user.full_name}/, sam_row.text)
    assert_select ".confirmed-signups-section dialog.missing-details-modal", text: /We need to collect payment from this participant\./
    assert_select ".confirmed-signups-section dialog.missing-details-modal", text: /Share this link with the participant so they can pay for the trip:/
    assert_select ".confirmed-signups-section dialog.missing-details-modal a[href='#{participant_link}']", text: "Date selection, waiver, and payment link"
  end

  test "trip details links payment amount to details modal for partially refunded payment" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Jordan",
      last_name: "Guest",
      email: "jordan-trip-payment@example.com",
      password: "password"
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1,
      arrival_date: signup.arrival_date,
      checkout_date: signup.checkout_date
    )
    signup.campsite_signup_minors.create!(
      first_name: "Mini",
      last_name: "Lee",
      age: 12,
      relationship: "Child"
    )
    payment = signup.payments.create!(
      source: "stripe",
      status: "partially_refunded",
      amount_cents: 10000,
      refunded_amount_cents: 3000,
      stripe_payment_intent_id: "pi_trip_details_refund",
      stripe_checkout_session_id: "cs_trip_details_refund",
      paid_at: Time.current,
      pricing_snapshot: {
        "amount_cents" => 10000,
        "adult_count" => 2,
        "counted_minor_count" => 1,
        "free_minor_count" => 0,
        "night_count" => 3,
        "extra_night_count" => 1,
        "first_two_nights_fee_cents" => 3000,
        "extra_night_fee_cents" => 1000,
        "minor_fee_cents" => 1500,
        "minor_extra_night_fee_cents" => 500,
        "uncounted_minor_age_limit" => 10
      }
    )
    payment.refunds.create!(
      amount_cents: 3000,
      status: "succeeded",
      initiated_by: "admin",
      refunded_by: users(:alex),
      refund_type: "admin_created",
      reason: "Overpayment",
      refunded_at: Time.current
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section tbody tr", text: /Sam Lee/ do
      assert_select ".admin-payment-status.warning-status", text: "Partially Refunded"
      assert_select "button.admin-payment-amount-link[data-action='modal#open']", text: "$100.00"
      assert_select "button", text: "Update", count: 0
      assert_select "dialog.transaction-details-modal" do
        assert_select "h2", "Payment details"
        assert_select "dt", text: "Amount Refunded"
        assert_select "dd", text: "$30.00"
        assert_select "dt", text: "Remaining refundable"
        assert_select "dd", text: "$70.00"
        fee_rows = css_select(".transaction-fee-table tbody tr").map { |row| row.text.squish }
        assert_includes fee_rows, "Sam Lee $30.00 $10.00 $40.00"
        assert_includes fee_rows, "Jordan Guest $30.00 $10.00 $40.00"
        assert_includes fee_rows, "Mini Lee $15.00 $5.00 $20.00"
        assert_select ".transaction-refund-action-row button.danger.secondary:not([disabled])", text: "Issue Refund"
        assert_select "dialog.refund-modal" do
          assert_select "h2", "Refund payment"
          assert_select "input[name='refund[amount]'][value='0.00']"
          assert_select "textarea[name='refund[reason]']"
          assert_select "input[name='refund[trip_expense]'][type='checkbox']"
          assert_select "input[type='submit'][value='Issue Refund']"
        end
        assert_select ".transaction-refunds-table", text: /Admin Created/
      end
    end
  end

  test "trip details shows trip expense refunds" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    payment = signup.payments.create!(
      source: "stripe",
      status: "partially_refunded",
      amount_cents: 8000,
      refunded_amount_cents: 2500,
      stripe_payment_intent_id: "pi_trip_expenses",
      stripe_checkout_session_id: "cs_trip_expenses",
      paid_at: Time.current
    )
    expense_refund = payment.refunds.create!(
      amount_cents: 1500,
      status: "succeeded",
      initiated_by: "admin",
      refunded_by: users(:alex),
      refund_type: "trip_expense",
      reason: "Firewood",
      refunded_at: Time.zone.local(2026, 6, 5, 18, 30)
    )
    payment.refunds.create!(
      amount_cents: 1000,
      status: "succeeded",
      initiated_by: "admin",
      refunded_by: users(:alex),
      refund_type: "admin_created",
      reason: "Overpayment",
      refunded_at: Time.zone.local(2026, 6, 5, 17, 30)
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h2", "Trip Expenses"
    assert_select "section.panel", text: /Trip Expenses/ do
      assert_select "th", text: "Participant"
      assert_select "th", text: "Amount"
      assert_select "th", text: "Refunded By"
      assert_select "th", text: "Reason"
      assert_select "th", text: "Date of Refund"
      assert_select "th", text: "Details"
      assert_select "tbody tr", count: 1
      assert_select "tbody tr", text: /Sam Lee/ do
        assert_select "td", text: "$15.00"
        assert_select "td", text: "Alex Rivera"
        assert_select "td", text: "Firewood"
        assert_select "td", text: "6/5/26"
        assert_select "[data-controller='payment-details-trigger'][data-payment-details-trigger-payment-id-value='#{payment.id}']"
        assert_select "button.button.secondary[data-action='payment-details-trigger#open']", text: "View"
      end
      assert_select "tbody tr", text: /Overpayment/, count: 0
    end
    assert_select "button.admin-payment-amount-link[data-payment-details-payment-id='#{payment.id}']", text: "$80.00"
  end

  test "trip details payment modal shows waived by admin" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.payments.create!(
      source: "waived",
      status: "waived",
      amount_cents: 0,
      waived_reason: "Board approved comp",
      created_by: users(:alex),
      pricing_snapshot: CampsiteSignupPricing.zero.snapshot
    )

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".confirmed-signups-section tbody tr", text: /Sam Lee/ do
      assert_select "button.admin-payment-amount-link[data-action='modal#open']", text: "$0.00"
      assert_select "dialog.transaction-details-modal" do
        assert_select "dt", text: "Waived By"
        assert_select "dd", text: "Alex Rivera"
        assert_select "dt", text: "Waived reason"
        assert_select "dd", text: "Board approved comp"
      end
    end
  end

  test "trip details shows trip revenue summary" do
    trip = trips(:yosemite)
    payment = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam)).payments.create!(
      source: "stripe",
      status: "partially_refunded",
      amount_cents: 10_000,
      refunded_amount_cents: 3_000,
      paid_at: Time.current
    )
    payment.refunds.create!(
      amount_cents: 2_000,
      status: "succeeded",
      initiated_by: "admin",
      refund_type: "admin_created",
      source: "stripe",
      currency: "usd"
    )
    payment.refunds.create!(
      amount_cents: 1_000,
      status: "succeeded",
      initiated_by: "admin",
      refund_type: "trip_expense",
      source: "stripe",
      currency: "usd"
    )
    trip.trip_payment_requests.create!(
      first_name: "Riley",
      last_name: "Stone",
      email: "riley@example.com",
      amount_cents: 2_500,
      reason: "Extra permit",
      status: "paid",
      paid_at: Time.current
    )

    get admin_trip_url(trip)

    assert_response :success
    assert_select "section.trip-revenue-panel" do
      assert_select "h2", "Trip Revenue"
      assert_select "tr", text: /Upper Pines site A12\s+\$100\.00\s+\$20\.00\s+\$80\.00/
      assert_select "tr", text: /Upper Pines site A13\s+\$0\.00\s+\$0\.00\s+\$0\.00/
      assert_select "tr.trip-revenue-subtotal", text: /Campsite revenue\s+\$80\.00/
      assert_select "tr", text: /One-time payment requests\s+\$25\.00/
      assert_select "tr.trip-revenue-total", text: /Total revenue\s+\$105\.00/
      assert_select "tr.trip-revenue-expense", text: /Trip expense refunds\s+-\$10\.00/
      assert_select "tr.trip-revenue-final", text: /Final trip revenue\s+\$95\.00/
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
    assert_select "select[name='trip[campsite_coordinator_id]']", count: 0
    assert_select ".coordinator-picker[data-controller='participant-picker']"
    assert_select "input[type='hidden'][name='trip[campsite_coordinator_id]'][data-participant-picker-target='input'][value='']"
    assert_select "button.participant-picker-button[role='combobox']", text: "Unassigned"
    assert_select "input.participant-picker-search[placeholder='Search coordinators']"
    assert_select "button.participant-picker-option[data-value='']", text: "Unassigned"
    assert_select "button.participant-picker-option[data-value='#{users(:alex).id}']", text: "Alex Rivera"
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
    assert_select ".coordinator-picker[data-controller='participant-picker']"
    assert_select "input[type='hidden'][name='trip[campsite_coordinator_id]'][value='']"
    assert_select "button.participant-picker-button[role='combobox']", text: "Unassigned"
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
