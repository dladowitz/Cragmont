require "application_system_test_case"

class RecurringGymMeetupsSystemTest < ApplicationSystemTestCase
  test "admin previews then creates four meetups through the browser" do
    visit new_session_path(return_to: new_admin_trip_path(trip_type: "gym_outing"))
    page.execute_script("arguments[0].value = arguments[1]", find_field("Email"), users(:alex).email)
    page.execute_script("arguments[0].value = arguments[1]", find_field("Password"), "password")
    login = find_button("Log in")
    page.execute_script("arguments[0].form.requestSubmit(arguments[0])", login)
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

    set_form_input "trip_name", "System recurring gym crew"
    set_form_input "trip_participant_capacity", "10"
    set_form_input "trip_location", "Movement Sunnyvale"
    set_form_input "gym_meetup_schedule_ends_on", "2027-02-19"
    set_form_input "trip_start_date", "2027-01-01"
    set_form_input "trip_meeting_time", "13:00"
    set_form_input "trip_status", "published"
    assert_field "Gym outing name", with: "System recurring gym crew"
    assert_field "Number of participants", with: "10"
    assert_field "Location", with: "Movement Sunnyvale"
    picker = find(".coordinator-picker")
    Selenium::WebDriver::Wait.new(timeout: 5).until do
      page.evaluate_script("Boolean(window.Stimulus?.getControllerForElementAndIdentifier(arguments[0], 'participant-picker'))", picker)
    end
    within picker do
      page.execute_script("arguments[0].click()", find("[role=combobox]"))
      assert_selector ".participant-picker-panel:not([hidden])"
      page.execute_script("arguments[0].click()", find("button[data-label='Alex Rivera']"))
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

  private

  def set_form_input(id, value)
    field = find("##{id}")
    page.execute_script(<<~JS, field, value)
      arguments[0].value = arguments[1]
      arguments[0].dispatchEvent(new Event('input', { bubbles: true }))
      arguments[0].dispatchEvent(new Event('change', { bubbles: true }))
    JS
  end
end
