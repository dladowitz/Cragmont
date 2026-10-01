require "test_helper"

class Admin::CampsiteReimbursementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    campsites(:yosemite_a).update!(registration_fee: "84.25")
    campsites(:yosemite_b).update!(registration_fee: "0")
    campsites(:jtree_a).update!(
      registration_fee: "92.50",
      registration_reimbursed_at: Time.zone.local(2026, 8, 18),
      registration_reimbursed_by: users(:sam),
      registration_reimbursement_method: "venmo",
      registration_reimbursement_recorded_by: users(:alex)
    )
    log_in_as(users(:alex))
  end

  test "defaults to positive-fee unreimbursed campsites" do
    excluded_day_trip_campsite = create_excluded_campsite!("Day Trip Site", "day_trip")
    excluded_class_campsite = create_excluded_campsite!("Class Trip Site", "class_trip")
    excluded_deleted_campsite = create_excluded_campsite!("Deleted Trip Site", "camping", deleted: true)

    get admin_campsite_reimbursements_url

    assert_response :success
    assert_select "form.campsite-reimbursement-filter-form[data-turbo='false']", count: 1
    assert_select "input[name='reimbursement_status[]'][value='unreimbursed'][checked]"
    assert_select "input[name='reimbursement_status[]'][value='reimbursed']:not([checked])"
    assert_select "input[name='reimbursement_status[]'][value='all']:not([checked])"
    assert_select ".campsite-reimbursement-filter span", text: "Unreimbursed", count: 1
    assert_select ".campsite-reimbursement-filter span", text: "Reimbursed", count: 1
    assert_select ".campsite-reimbursement-filter span", text: "All", count: 1
    assert_select ".campsite-reimbursement-filter-actions input[type='submit'][value='Apply']", count: 1
    assert_select ".campsite-reimbursement-filter-actions button[type='submit'][name='format'][value='csv']", text: "Download CSV Report", count: 1
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_a).id}", count: 1
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_b).id}", count: 0
    assert_select "#campsite-reimbursement-#{campsites(:jtree_a).id}", count: 0
    assert_select "#campsite-reimbursement-#{excluded_day_trip_campsite.id}", count: 0
    assert_select "#campsite-reimbursement-#{excluded_class_campsite.id}", count: 0
    assert_select "#campsite-reimbursement-#{excluded_deleted_campsite.id}", count: 0
  end

  test "all filter shows every campsite from non-deleted camping trips" do
    trips(:jtree).update!(status: "archived")

    get admin_campsite_reimbursements_url, params: { filters: "1", reimbursement_status: [ "all" ] }

    assert_response :success
    assert_select "input[name='reimbursement_status[]'][value='all'][checked]"
    assert_select "table.campsite-reimbursement-table", count: 2
    assert_select "th", text: "Campground", count: 2
    assert_select "th", text: "Site Number", count: 2
    assert_select "th", text: "Registered by", count: 2
    assert_select "th", text: "Fees paid", count: 2
    assert_select "th", text: "Reimbursed", count: 2
    assert_select "th", text: "Reimbursed On", count: 2
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_a).id}" do
      assert_select "td", text: "Upper Pines"
      assert_select "td", text: "A12"
      assert_select "td", text: "Alex Rivera"
      assert_select "td", text: "$84.25"
      assert_select "td", text: /No/
      assert_select "td", text: "—"
    end
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_b).id}" do
      assert_select "td", text: "None"
      assert_select "td", text: "$0.00"
    end
    assert_select "#campsite-reimbursement-#{campsites(:jtree_a).id}" do
      assert_select "td", text: "Yes"
      assert_select "td", text: "Aug 18, 2026"
    end
    assert_select "#campsite-reimbursement-trip-#{trips(:jtree).id} h3", text: "Joshua Tree Winter"
    assert_select "#campsite-reimbursement-trip-#{trips(:jtree).id}", text: /Archived/
  end

  test "reimbursed filter shows only campsites with a reimbursement date" do
    get admin_campsite_reimbursements_url, params: { filters: "1", reimbursement_status: [ "reimbursed" ] }

    assert_response :success
    assert_select "input[name='reimbursement_status[]'][value='reimbursed'][checked]"
    assert_select "#campsite-reimbursement-#{campsites(:jtree_a).id}", count: 1
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_a).id}", count: 0
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_b).id}", count: 0
  end

  test "multiple reimbursement filters combine their results" do
    get admin_campsite_reimbursements_url, params: {
      filters: "1",
      reimbursement_status: %w[unreimbursed reimbursed]
    }

    assert_response :success
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_a).id}", count: 1
    assert_select "#campsite-reimbursement-#{campsites(:jtree_a).id}", count: 1
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_b).id}", count: 0
  end

  test "downloads a CSV report using the selected filters" do
    get admin_campsite_reimbursements_url(format: :csv), params: {
      filters: "1",
      reimbursement_status: [ "reimbursed" ]
    }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "campsite-reimbursements-#{Date.current.iso8601}.csv", response.headers["Content-Disposition"]

    report = CSV.parse(response.body, headers: true)
    assert_equal [
      "Trip",
      "Trip Start",
      "Trip End",
      "Campground",
      "Site Number",
      "Registered by",
      "Fees paid",
      "Reimbursed",
      "Reimbursed On"
    ], report.headers
    assert_equal 1, report.size
    assert_equal "Joshua Tree Winter", report.first["Trip"]
    assert_equal "H4", report.first["Site Number"]
    assert_equal "92.50", report.first["Fees paid"]
    assert_equal "Yes", report.first["Reimbursed"]
    assert_equal "2026-08-18", report.first["Reimbursed On"]
  end

  test "groups trips oldest first and campsites by campground and site number" do
    older_trip = create_camping_trip!("Ancient Granite", Date.new(2025, 5, 1))
    create_campsite!(older_trip, "Z9", registration_fee_cents: 5_000)
    campsites(:yosemite_b).update!(registration_fee: "60")

    get admin_campsite_reimbursements_url

    assert_operator response.body.index("Ancient Granite"), :<, response.body.index("Yosemite Valley Spring")
    assert_operator response.body.index("campsite-reimbursement-#{campsites(:yosemite_a).id}"), :<, response.body.index("campsite-reimbursement-#{campsites(:yosemite_b).id}")
  end

  test "coordinator sees every outstanding campsite but can record only for assigned trips" do
    coordinator = create_user!("coordinator-reimbursements@example.com")
    trips(:yosemite).update!(campsite_coordinator: coordinator)
    campsites(:jtree_a).update!(
      registration_reimbursed_at: nil,
      registration_reimbursed_by: nil,
      registration_reimbursement_method: nil,
      registration_reimbursement_recorded_by: nil
    )
    delete session_url
    log_in_as(coordinator)

    get admin_campsite_reimbursements_url

    assert_response :success
    assert_select "#campsite-reimbursement-#{campsites(:yosemite_a).id}" do
      assert_select "button", text: "Record Reimbursement", count: 1
    end
    assert_select "#campsite-reimbursement-#{campsites(:jtree_a).id}" do
      assert_select "button", text: "Record Reimbursement", count: 0
    end
  end

  test "records reimbursement and returns to the preserved index filter" do
    patch record_registration_reimbursement_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a)), params: {
      return_to: "campsite_reimbursements",
      filters: "1",
      reimbursement_status: %w[unreimbursed reimbursed],
      campsite: {
        registration_reimbursed_at: "2026-09-04",
        registration_reimbursed_by_id: users(:sam).id,
        registration_reimbursement_method: "venmo",
        registration_reimbursement_notes: "Sent from the finance queue"
      }
    }

    assert_redirected_to admin_campsite_reimbursements_url(
      filters: "1",
      reimbursement_status: %w[unreimbursed reimbursed]
    )
    campsite = campsites(:yosemite_a).reload
    assert_equal Date.new(2026, 9, 4), campsite.registration_reimbursed_at.to_date
    assert_equal users(:alex), campsite.registration_reimbursement_recorded_by
    assert_equal "On belay! Campsite reimbursement was recorded.", flash[:notice]
  end

  test "invalid reimbursement returns to the index with an error" do
    patch record_registration_reimbursement_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a)), params: {
      return_to: "campsite_reimbursements",
      reimbursement_status: [ "all" ],
      campsite: {
        registration_reimbursed_at: "",
        registration_reimbursed_by_id: users(:sam).id,
        registration_reimbursement_method: "venmo"
      }
    }

    assert_redirected_to admin_campsite_reimbursements_url(filters: "1", reimbursement_status: [ "all" ])
    assert_match "Wow, that was a whipper.", flash[:alert]
    assert_nil campsites(:yosemite_a).reload.registration_reimbursed_at
  end

  private

  def create_excluded_campsite!(name, trip_type, deleted: false)
    trip = create_camping_trip!(name, Date.new(2027, 1, 1))
    campsite = create_campsite!(trip, "X1", registration_fee_cents: 7_500)
    trip.update_column(:trip_type, trip_type)
    trip.update_column(:deleted_at, Time.current) if deleted
    campsite
  end

  def create_camping_trip!(name, start_date)
    Trip.create!(
      name: name,
      location: "Test Crag",
      start_date: start_date,
      end_date: start_date + 2.days,
      description: "A test trip.",
      status: "published",
      trip_type: "camping"
    )
  end

  def create_campsite!(trip, site_number, registration_fee_cents:)
    Campsite.create!(
      trip: trip,
      campground: campgrounds(:upper_pines),
      site_number: site_number,
      arrival_date: trip.start_date,
      checkout_date: trip.end_date,
      participant_capacity: 4,
      car_capacity: 1,
      registration_fee_cents: registration_fee_cents
    )
  end

  def create_user!(email)
    User.create!(
      first_name: "Casey",
      last_name: "Crux",
      email: email,
      password: "password"
    )
  end
end
