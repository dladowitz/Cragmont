require "test_helper"

class Admin::TripsControllerTest < ActionDispatch::IntegrationTest
  test "can view trips index" do
    get admin_trips_url

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-public-link", "Public Site"
    assert_select ".admin-nav a", text: "Trips"
    assert_select ".admin-nav a", text: "Public Site", count: 0
    assert_select "h2", "Trips"
    assert_select "th", text: "Participant Capacity"
    assert_select "th", text: "Signed Up"
    assert_select "td", text: /Yosemite Valley Spring/
    assert_select "td", text: "Alex Rivera"
  end

  test "can view trip details with campsites" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")
    attach_test_waiver_to(signup)
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa-admin@example.com", password: "password")
    waitlisted_signup = create_waitlisted_signup!(trip: trips(:yosemite), user: waitlisted_user)
    allowed_user = User.create!(first_name: "Zora", last_name: "Allowed", email: "zora-admin@example.com", password: "password")
    create_waitlisted_signup!(trip: trips(:yosemite), user: allowed_user, waitlist_eligible_at: Time.current)

    get admin_trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".admin-public-link", "Public Site"
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
      assert_select ".table-actions > [data-controller='modal']", count: 0
      assert_select "dialog.confirmation-modal", text: /Delete campsite\?/, count: 0
      assert_select "form[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}']", count: 0
    end
    assert_select "#admin-campsite-#{campsites(:yosemite_b).id}" do
      assert_select ".table-actions button", text: "Delete", count: 0
      assert_select "dialog.confirmation-modal", text: /Delete campsite\?/, count: 0
      assert_select "form[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_b))}']", count: 0
    end
    assert_select ".campsite-notes", text: /Close to bathrooms/
    assert_select ".confirmed-signups-section" do
      assert_select "h4", "Confirmed participants"
      assert_select "td", text: "Sam Lee"
      assert_select "th", text: "Dates"
      assert_select "th", text: "Attendance", count: 0
      assert_select "td", text: "Jun 13-Jun 15"
      assert_select ".missing-value", text: "Missing", count: 0
      assert_select "td", text: "Willa Wait", count: 0
      assert_select ".admin-minor-list", text: /Mika Lee, age 12, Child/
      assert_select "td", text: "555-0101"
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
      assert_select "td", text: "Willa Wait"
      assert_select "td", text: "Zora Allowed"
      assert_select "th", text: "Attendance", count: 0
      assert_select "td", text: "Not chosen yet", count: 0
      assert_select "th", text: /Allow Signup/
      assert_select "th", text: "Allowed to Signup", count: 0
      assert_select ".tooltip-heading.info-tooltip[aria-label='Participants can sign themselves up from the waitlist']", text: /Allow Signup/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Participants can sign themselves up from the waitlist']", text: /Participants can sign themselves up from the waitlist/
      assert_select "th", text: /Update Signup Ability/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Enable participant to sign themselves up from the waitlist']", text: /Update Signup Ability/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Enable participant to sign themselves up from the waitlist']", text: /Enable participant to sign themselves up from the waitlist/
      assert_select "th", text: "Eligibility", count: 0
      assert_select "th", text: "Action", count: 0
      assert_select "td", text: "Non-member"
      assert_select "td", text: "No"
      assert_select "td", text: "Yes"
      assert_select "button", text: "Allow Signup"
      assert_select "button", text: "Allow to Signup", count: 0
      assert_select "button[title='Enable participant to sign themselves up from the waitlist']", count: 0
      assert_select "button", text: "Allow Participant to Signup", count: 0
      assert_select "button", text: "Revoke Signup"
      assert_select "button", text: "Revoke Signup Ability", count: 0
      assert_select "select[name='campsite_signup[campsite_id]']", count: 0
      assert_select "th", text: /Add to Campsite/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Adds a participant directly to a campsite']", text: /Add to Campsite/
      assert_select ".tooltip-heading.info-tooltip[aria-label='Adds a participant directly to a campsite']", text: /Adds a participant directly to a campsite/
      assert_select "th", text: "Move to Campsite", count: 0
      assert_select "button", text: "Add to Campsite", count: 0
      assert_select ".trip-waitlist-section tbody > tr > td > div[data-controller='modal'] > button", text: "Add", count: 2
      assert_select "dialog.signup-modal", text: /Add Willa Wait to a campsite/
      assert_select ".admin-campsite-choice-row", text: /Upper Pines site A12/
      assert_select ".admin-campsite-choice-row", text: /Upper Pines site A13/
      assert_select ".admin-campsite-choice-stats", text: /capacity/
      assert_select "form[action='#{move_to_campsite_admin_trip_campsite_signup_path(trips(:yosemite), waitlisted_signup)}']" do
        assert_select "input[name='campsite_signup[campsite_id]'][value='#{campsites(:yosemite_a).id}']"
        assert_select "button", text: "Add"
      end
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

  test "published trip requires campsite coordinator" do
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

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Campsite coordinator can't be blank/
  end

  test "can render edit trip form" do
    get edit_admin_trip_url(trips(:yosemite))

    assert_response :success
  end

  test "can delete trip" do
    trip = trips(:jtree)

    assert_difference "Trip.count", -1 do
      delete admin_trip_url(trip)
    end

    assert_redirected_to admin_trips_url
  end
end
