require "application_system_test_case"

class RecurringGymMeetupsSystemTest < ApplicationSystemTestCase
  test "admin previews then creates four meetups through the browser" do
    visit new_session_path(return_to: new_admin_trip_path(trip_type: "gym_outing"))
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_current_path new_admin_trip_path(trip_type: "gym_outing")

    assert_no_field "Repeat through"
    assert_no_selector "label[for=trip_campsite_coordinator_id] .required-marker"
    select "Twice monthly — first and third week", from: "Repeat"
    assert_field "Repeat through"
    assert_selector "label[for=trip_campsite_coordinator_id] .required-marker", text: "*"
    select "Does not repeat", from: "Repeat"
    assert_no_field "Repeat through"
    assert_no_selector "label[for=trip_campsite_coordinator_id] .required-marker"
    select "Twice monthly — first and third week", from: "Repeat"

    fill_in "Repeat through", with: Date.new(2027, 2, 19)
    find("#gym_meetup_schedule_ends_on").send_keys(:escape)
    fill_in "Gym outing name", with: "System recurring gym crew"
    fill_in "Number of participants", with: 10
    fill_in "trip_location", with: "Movement Sunnyvale"
    fill_in "Trip date", with: Date.new(2027, 1, 1)
    # Native date popovers can otherwise intercept the next Selenium click.
    find("#trip_start_date").send_keys(:escape)
    fill_in "Meeting time", with: Time.zone.local(2027, 1, 1, 13)
    find("#trip_meeting_time").send_keys(:escape)
    select "Published", from: "Status"
    within ".coordinator-picker" do
      find("[role=combobox]").click
      assert_selector ".participant-picker-panel:not([hidden])"
      find("button[data-label='Alex Rivera']").send_keys(:enter)
      assert_selector "[role=combobox]", text: "Alex Rivera"
    end

    assert_no_difference "Trip.count" do
      preview = find_button("Preview meetup dates")
      page.execute_script("arguments[0].form.requestSubmit(arguments[0])", preview)
      assert_selector "[role=status] h3", text: "4 meetup dates"
      assert_selector "[role=status] li", text: "Friday, February 19, 2027"
    end
    assert_field "Gym outing name", with: "System recurring gym crew"
    assert_selector ".coordinator-picker [role=combobox]", text: "Alex Rivera"
    assert_button "Create Trip"

    assert_difference "Trip.count", 4 do
      submit = find_button("Create Trip")
      page.execute_script("arguments[0].form.requestSubmit(arguments[0])", submit)
      assert_text "On belay! 4 gym meetups were created."
    end
    trips = Trip.where(name: "System recurring gym crew").order(:start_date)
    assert_current_path admin_trip_path(trips.first)
    assert_equal %w[2027-01-01 2027-01-15 2027-02-05 2027-02-19], trips.map { |trip| trip.start_date.iso8601 }
    assert trips.all?(&:published?)
    assert_equal [ users(:alex).id ], trips.pluck(:campsite_coordinator_id).uniq
  end
end
