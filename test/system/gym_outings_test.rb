require "application_system_test_case"

class GymOutingsSystemTest < ApplicationSystemTestCase
  setup do
    @trip = Trip.create!(
      trip_type: "gym_outing", name: "System test gym laps", location: "Test Climbing Gym",
      start_date: Date.current + 7, meeting_time: "18:00", end_time: "20:00",
      status: "published", participant_capacity: 1,
      whatsapp_group: "https://chat.whatsapp.com/system-test-private-invite",
      photo_album_url: "https://example.com/system-test-private-album",
      description: "Photos: https://example.com/system-test-private-album"
    )
  end

  test "member resources return to the gym outing after login and disappear after logout" do
    visit trip_path(@trip)
    assert_selector ".trip-whatsapp-link", text: "log in to reveal"
    assert_no_selector "a[href='#{@trip.whatsapp_group}']", visible: :all
    assert_no_selector "a[href='#{@trip.photo_album_url}']", visible: :all
    assert_not_includes page.html, "system-test-private-invite"
    assert_not_includes page.html, "system-test-private-album"

    find(".trip-whatsapp-link").click
    assert_current_path new_session_path(return_to: trip_path(@trip))
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in"

    assert_current_path trip_path(@trip)
    assert_selector ".trip-whatsapp-link[href='#{@trip.whatsapp_group}']", text: "Join the WhatsApp Group"
    assert_selector ".trip-photo-album-link[href='#{@trip.photo_album_url}']", text: "Photo Album"

    click_button "Log out"
    assert_current_path root_path
    page.go_back
    assert_current_path trip_path(@trip)
    assert_selector ".trip-whatsapp-link", text: "log in to reveal"
    assert_no_selector "a[href='#{@trip.whatsapp_group}']", visible: :all
    assert_no_selector "a[href='#{@trip.photo_album_url}']", visible: :all
    assert_not_includes page.html, "system-test-private-invite"
    assert_not_includes page.html, "system-test-private-album"
  end

  test "a young minor uses a gym spot and switches a one spot outing to the waitlist" do
    visit new_session_path(return_to: trip_path(@trip))
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_current_path trip_path(@trip)
    click_button "Sign Up"

    within "dialog.day-trip-signup-modal[open]" do
      assert_selector "form[data-signature-uncounted-minor-age-limit-value='0']"
      assert_no_selector ".capacity-warning"
      assert_button "Next"
      check "Add one minor"
      fill_in "Age", with: "8"
      assert_field "Age", with: "8"

      assert_selector ".capacity-warning", text: "You can sign up for the waitlist"
      assert_button "Join waitlist", disabled: false
      assert_no_button "Next"

      uncheck "Add one minor"
      assert_no_selector ".capacity-warning"
      assert_button "Next", disabled: false
    end
  end
end
