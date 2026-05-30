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
    waitlisted_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: waitlisted_user)
    waitlisted_signup.waitlisted!

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
    assert_select "h3", "Upper Pines"
    assert_select "h4", text: "Site A12"
    assert_select ".table-actions [data-controller='modal'] button.link-button", text: "Delete"
    assert_select "dialog.confirmation-modal", text: /Delete campsite\?/
    assert_select "dialog.confirmation-modal", text: /This will not remove signed-up participants from the trip\./
    assert_select "dialog.confirmation-modal form[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}']"
    assert_select ".campsite-notes", text: /Close to bathrooms/
    assert_select ".confirmed-signups-section" do
      assert_select "h4", "Confirmed participants"
      assert_select "td", text: "Sam Lee"
      assert_select "th", text: "Attendance"
      assert_select "td", text: "Jun 13-Jun 15"
      assert_select "td", text: "Willa Wait", count: 0
      assert_select ".admin-minor-list", text: /Mika Lee, age 12, Child/
      assert_select "td", text: "555-0101"
      assert_select "th", text: "Status", count: 0
      assert_select ".status.confirmed-status", count: 0
    end
    assert_select ".waitlisted-signups-section" do
      assert_select "h4", "Waitlisted participants"
      assert_select "td", text: "Willa Wait"
      assert_select "td", text: "Jun 12-Jun 15"
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
    assert_select "td", text: /Missing/
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
