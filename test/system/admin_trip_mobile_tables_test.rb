require "application_system_test_case"

class AdminTripMobileTablesTest < ApplicationSystemTestCase
  setup do
    trip = trips(:yosemite)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    create_waitlisted_signup!(trip: trip, user: users(:alex))
    signup.payments.create!(source: "manual", status: "paid", amount_cents: 1_000,
      manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)
    TripPaymentRequest.create!(trip: trip, first_name: "Taylor", last_name: "Climber",
      email: "taylor@example.test", amount_cents: 2_000, reason: "Shared campsite supplies")
    TripDetailsEmailTemplate.ensure_defaults!
    template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite", name: "Yosemite")
    sent_email = TripDetailsEmail.create!(trip: trip, trip_details_email_template: template,
      status: "sent", subject: "Trip details", body_markdown: "Trip details",
      rendered_html_snapshot: "<p>Trip details</p>", rendered_text_snapshot: "Trip details",
      template_name_snapshot: template.name, template_area_key_snapshot: template.area_key,
      sent_at: Time.current, sent_by: users(:alex))
    sent_email.trip_details_email_recipients.create!(recipient_name: users(:sam).full_name,
      email: users(:sam).email, campsite_label: "Upper Pines A12",
      delivery_status: "delivered", delivered_at: Time.current)

    visit new_session_path
    fill_in "Email", with: users(:alex).email
    fill_in "Password", with: "password"
    click_button "Log in", exact: true
    assert_selector ".account-nav"
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "trip records and transactions need no sideways scrolling on phones" do
    [ 320, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: false)
      visit admin_trip_path(trips(:yosemite))
      assert_record_tables_fit(width, ".admin-signups-table", ".trip-payment-requests-table", ".trip-revenue-table")
      assert_text "Shared campsite supplies"
      assert_selector ".admin-signups-table td[data-label='Payment']"
      assert_selector ".trip-payment-requests-table .trip-payment-request-actions button", text: "Copy Link"

      visit admin_trip_transactions_path(trips(:yosemite))
      assert_record_tables_fit(width, ".transactions-table")
      within ".transactions-table" do
        assert_text users(:sam).full_name
        click_button "View"
      end
      dialog = find("dialog.transaction-details-modal[open]")
      within dialog do
        assert_record_tables_fit(width, ".transaction-fee-table")
        assert_selector ".transaction-fee-table td[data-label='First 2 nights']"
        assert_operator dialog.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "Payment dialog at #{width}px"
        click_button "Close"
      end

      visit admin_trip_trip_details_email_path(trips(:yosemite))
      assert_record_tables_fit(width, ".trip-details-email-recipient-table")
      assert_text users(:sam).email
      assert_text "Upper Pines A12"
    end
  end

  test "day trip participants and waitlist reflow with their actions visible" do
    trip = Trip.create!(trip_type: "day_trip", name: "Castle Rock Day Trip", location: "Castle Rock",
      start_date: Date.new(2026, 10, 12), description: "Single day cragging.", status: "published",
      meeting_time: "08:30", meeting_location: "Castle Rock entrance",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "Meet at the main wall.", participant_capacity: 1,
      climbing_types: [ "sport" ])
    DayTripSignup.create!(trip: trip, user: users(:sam), climbing_abilities: [ "top_rope" ])
    DayTripSignup.create!(trip: trip, user: users(:alex), climbing_abilities: [ "lead" ], status: "waitlisted")

    [ 320, 390 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: false)
      visit admin_trip_path(trip)
      assert_record_tables_fit(width, ".day-trip-participants-panel > table.admin-record-table",
        ".day-trip-waitlist-panel > table.admin-record-table")
      assert_selector ".day-trip-participants-panel td[data-label='Climbing Skills']", text: "Top rope"
      assert_button "Move to Waitlist"
      assert_button "Move onto Trip"
    end
  end

  private

  def assert_record_tables_fit(width, *selectors)
    selectors.each do |selector|
      assert_selector selector
      all(selector).each do |table|
        assert_equal "grid", table.first("tbody > tr").native.css_value("display")
        assert_operator table.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "#{selector} at #{width}px"
        table.all(":scope > tbody > tr > td").each do |cell|
          assert_operator cell.evaluate_script("this.scrollWidth - this.clientWidth"), :<=, 1, "#{selector} cell at #{width}px"
        end
      end
    end
  end
end
