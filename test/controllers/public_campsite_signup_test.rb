require "test_helper"

class PublicCampsiteSignupTest < ActionDispatch::IntegrationTest
  FakeStripeCheckoutSessionCreator = Struct.new(:payment, :success_url, :cancel_url, keyword_init: true) do
    def call
      payment.update!(
        stripe_checkout_session_id: "cs_test_#{payment.id}",
        checkout_url: "https://checkout.stripe.com/c/pay/#{payment.id}",
        checkout_expires_at: payment.checkout_expires_at || 30.minutes.from_now
      )
      payment
    end
  end

  test "root renders and links to trips" do
    get root_url

    assert_response :success
    assert_select "h1", text: "Climbing"
    assert_select "h1", text: "Camping"
    assert_select "h1", text: "Community"
    assert_select "p", text: /Yosemite/
    assert_select ".home-mobile-beta-notice", count: 0
    assert_select "a[href='#{trips_path}']", text: /View trips/
    assert_select "script[src*='googletagmanager.com']", count: 0
  end

  test "trips index shows published trips and hides unpublished trips" do
    class_trip = create_class_trip!(name: "Intro to Anchors")
    day_trip = Trip.create!(
      trip_type: "day_trip",
      name: "Castle Rock Day",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 9, 19),
      status: "published",
      meeting_time: "08:30",
      meeting_location: "Castle Rock parking lot",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "If you are running late, meet us at the main wall.",
      participant_capacity: 8,
      climbing_types: [ "sport" ]
    )

    get trips_url

    assert_response :success
    assert_select ".trip-card[href='#{trip_path(trips(:yosemite))}'] h2", text: "Yosemite Valley Spring"
    assert_select ".trip-card[href='#{trip_path(trips(:yosemite))}'] .date-range-desktop", text: /June 12, 2026\s*to June 15, 2026/
    assert_select ".trip-card[href='#{trip_path(trips(:yosemite))}'] .date-range-mobile", text: /06\/12\/26\s*to 06\/15\/26/
    assert_select ".trip-card[href='#{trip_path(trips(:yosemite))}'] .trip-card-meta", text: /Open Spaces\s*10 spaces/
    assert_select ".trip-card[href='#{trip_path(trips(:yosemite))}'] .trip-card-meta", text: /Capacity/, count: 0
    assert_select ".trip-card[href='#{trip_path(class_trip)}'] .trip-card-meta", text: /Open Spaces/, count: 0
    assert_select ".trip-card[href='#{trip_path(class_trip)}'] .trip-type-badge.external-class-badge", text: "External Class"
    assert_select ".trip-card[href='#{trip_path(day_trip)}'] .trip-type-badge.day-trip-badge", text: "Day Trip"
    assert_select ".trip-card[href='#{trip_path(trips(:jtree))}']", count: 0
    assert_select "a", text: "View trip", count: 0
    assert_select "a[href='#{past_trips_trips_path}']", text: "Past Trips"
    assert_select ".archived-trips-panel", count: 0
    assert_select ".trips-faq-callout a[href='#{what_to_expect_trips_path}']", text: "camping trips"
    assert_select ".trips-faq-callout a[href='#{day_trip_what_to_expect_trips_path}']", text: "day trips."
    assert_select ".background-image-caption", "Regular Northwest Face, Half Dome"
  end

  test "camping trip what to expect page renders" do
    get what_to_expect_trips_url

    assert_response :success
    assert_select "h1", "What to Expect on a Camping Trip"
    assert_select "h2", "Camping trips"
    assert_select "h2", text: "Day trips", count: 0
    assert_select ".content-page-markdown", text: /shared campsites/
    assert_select ".background-image-caption", "Fairview Dome, Yosemite National Park"
  end

  test "day trip what to expect page renders" do
    get day_trip_what_to_expect_trips_url

    assert_response :success
    assert_select "h1", "What to Expect on a Day Trip"
    assert_select "h2", "Day trips"
    assert_select ".content-page-markdown a[href='/trips/how-to-think-about-safety']", text: "How to think about safety on trips"
    assert_select ".background-image-caption", "Fairview Dome, Yosemite National Park"
  end

  test "trip safety page renders" do
    get safety_trips_url

    assert_response :success
    assert_select "h1", "How to think about safety on trips"
    assert_select "h2", "Before you trust a rope"
    assert_select ".content-page-markdown", text: /No one at Cragmont is a certified guide/
  end

  test "public day trip detail renders mobile hero image block" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Day",
      location: "Mount Tam, CA",
      start_date: Date.new(2026, 9, 12),
      status: "published",
      meeting_time: "19:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      description: "**Vent 5** is a sport climbing area on the Marin Coast.\n\n## Parking\n\nIt fills up quick here.",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      campsite_coordinator: users(:alex),
      participant_capacity: 8,
      sun_exposure: "Afternoon sun",
      climbing_types: [ "sport" ],
      whatsapp_group: "https://chat.whatsapp.com/vent5",
      weather_url: "https://forecast.weather.gov/vent5",
      mountain_project_url: "https://www.mountainproject.com/area/vent5",
      guide_book_url: "https://example.com/guide-book",
      photo_album_url: "https://photos.app.goo.gl/vent5"
    )

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-type-badge.day-trip-badge", text: "Day Trip"
    assert_select ".trip-summary-header .trips-faq-callout", text: /day trip/
    assert_select ".trip-summary-header .trips-faq-callout a[href='#{day_trip_what_to_expect_trips_path}']", text: "here."
    assert_select ".trip-summary-copy .trip-title-line" do
      assert_select ".trip-title-resource-link", count: 0
    end
    assert_select ".trip-summary-notices .trip-resource-link", count: 5
    assert_select ".trip-summary-notices a.trip-whatsapp-link[href='https://chat.whatsapp.com/vent5'][target='_blank'][rel='noopener']", text: "Join the WhatsApp Group"
    assert_select ".trip-summary-notices a.trip-weather-link[href='https://forecast.weather.gov/vent5'][target='_blank'][rel='noopener']", text: "Weather"
    assert_select ".trip-summary-notices a.trip-mountain-project-link[href='https://www.mountainproject.com/area/vent5'][target='_blank'][rel='noopener']", text: "Mountain Project"
    assert_select ".trip-summary-notices a.trip-guide-book-link[href='https://example.com/guide-book'][target='_blank'][rel='noopener']", text: "Guide Book"
    assert_select ".trip-summary-notices a.trip-photo-album-link[href='https://photos.app.goo.gl/vent5'][target='_blank'][rel='noopener']", text: "Photo Album"
    assert_select ".trip-overview .content-page-markdown", count: 0
    assert_select ".day-trip-description-panel" do
      assert_select ".content-page-markdown strong", "Vent 5"
      assert_select ".content-page-markdown h2", "Parking"
      assert_select ".content-page-markdown", text: /It fills up quick here/
    end
    assert_operator response.body.index("Crag Plan"), :<, response.body.index("Description")
    assert_select ".trip-show-mobile-hero" do
      assert_select "h1", "Vent 5 Day"
      assert_select ".trip-show-mobile-location", "Mount Tam, CA"
      assert_select ".trip-show-mobile-dates", text: /September 12, 2026 at 7:00pm/
      assert_select ".trip-whatsapp-mobile-link[href='https://chat.whatsapp.com/vent5'][target='_blank'][rel='noopener']", text: "Join the WhatsApp Group"
      assert_select ".trip-weather-mobile-link[href='https://forecast.weather.gov/vent5'][target='_blank'][rel='noopener']", text: "Weather"
      assert_select ".trip-photo-album-mobile-link[href='https://photos.app.goo.gl/vent5'][target='_blank'][rel='noopener']", text: "Photo Album"
      assert_select ".trip-show-mobile-hero-caption", "IRS Wall, Joshua Tree"
    end
    assert_select ".day-trip-resources-panel", count: 0
    assert_select ".day-trip-coordinator-panel" do
      assert_select "h2", "Trip Coordinator"
      assert_select ".details-list", text: /Alex Rivera/
      assert_select ".details-list a[href='mailto:alex@example.com']", text: "alex@example.com"
      assert_select ".details-list", text: /555-0100/, count: 0
    end
    assert_operator response.body.index("Trip Coordinator"), :<, response.body.index("Safety Reminder")
  end

  test "public class detail renders external event information" do
    ContentPage.current!("class_reminder").update!(
      title: "Class Reminder",
      body: "## Class Details\n\nRegister with the guide company."
    )
    trip = create_class_trip!(
      name: "Intro to Anchors",
      description: "Learn **anchors** from certified guides.",
      class_discount_code: "CRAG10",
      class_discount_amount: "$25 off",
      class_original_price: "250",
      class_offers_discount: true,
      class_discounted_price: "225",
      whatsapp_group: "https://chat.whatsapp.com/class-public",
      photo_album_url: "https://photos.app.goo.gl/class-public"
    )
    ClassSignup.create!(trip: trip, user: users(:sam))

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-type-badge.external-class-badge", text: "External Class"
    assert_select ".trip-summary-header", text: /Taught by/
    assert_select "a[href='https://example.com/vertical-world'][target='_blank'][rel='noopener']", text: "Vertical World Guides"
    assert_select "a.button[href='https://example.com/classes/anchors'][target='_blank'][rel='noopener']", text: "Register with Vertical World Guides", count: 1
    assert_select ".class-trip-description-panel a.button[href='https://example.com/classes/anchors'][target='_blank'][rel='noopener']", text: "Register with Vertical World Guides", count: 1
    assert_select ".class-trip-description-panel .class-registration-card .day-trip-signup-action"
    assert_select ".trip-resource-links a[href='https://example.com/classes/anchors']", count: 0
    assert_select ".trip-mobile-resource-link[href='https://example.com/classes/anchors']", count: 0
    assert_select ".class-trip-description-panel .class-registration-note", text: "You must register and pay on the guiding company's website to be officially signed up."
    assert_select ".class-trip-details-panel .class-registration-note", count: 0
    assert_select ".class-trip-details-panel h2", "Cost Details"
    assert_select ".class-trip-details-panel", text: /Max class size/, count: 0
    assert_select ".class-trip-details-panel", text: /Original price\s*\$250/
    assert_select ".class-trip-details-panel", text: /Discount code\s*CRAG10/
    assert_select ".class-trip-details-panel", text: /Discount amount\s*\$25 off/
    assert_select ".class-trip-details-panel", text: /Discounted price\s*\$225/
    assert_select ".class-trip-description-panel .content-page-markdown strong", "anchors"
    assert_operator response.body.index("class-trip-description-panel"), :<, response.body.index("class-trip-details-panel")
    assert_operator response.body.index("class-trip-description-panel"), :<, response.body.index("class-reminder-panel")
    assert_operator response.body.index("class-reminder-panel"), :<, response.body.index("class-trip-details-panel")
    assert_select ".class-trip-participants-panel td", text: "Sam L."
    assert_select ".class-trip-overview .stats", text: /Open Spaces/, count: 0
    assert_select ".class-trip-overview .danger-status", text: /Class Full/, count: 0
    assert_select ".class-trip-participants-panel", text: /This indicates to other Cragmont participants you have signed up/
    assert_select ".class-trip-participants-panel", text: /You must signup on Vertical World Guides' website to be enrolled\. This does not automatically sync with their signups\./
    assert_select ".class-reminder-panel .content-page-markdown h2", count: 0
    assert_select ".class-reminder-panel .content-page-markdown", text: /Class Details/, count: 0
    assert_select ".class-reminder-panel .content-page-markdown", text: /Register with the guide company/
    assert_select ".trips-faq-callout", count: 0
    assert_select ".day-trip-safety-panel .content-page-markdown", text: /Climbing is dangerous/, count: 0
    assert_select ".waiver-form", count: 0
  end

  test "public class detail hides discount fields when class does not offer a discount" do
    trip = create_class_trip!(
      class_original_price: "250",
      class_discount_code: "CRAG10",
      class_discount_amount: "$25 off",
      class_discounted_price: "225"
    )

    get trip_url(trip)

    assert_response :success
    assert_select ".class-trip-details-panel", text: /Price\s*\$250/
    assert_select ".class-trip-details-panel", text: /Original price/, count: 0
    assert_select ".class-trip-details-panel", text: /Discount code/, count: 0
    assert_select ".class-trip-details-panel", text: /Discount amount/, count: 0
    assert_select ".class-trip-details-panel", text: /Discounted price/, count: 0
  end

  test "public class signup marks intent without waiver or payment" do
    trip = create_class_trip!(participant_capacity: 2)
    log_in_as(users(:sam))

    get trip_url(trip)
    assert_response :success
    assert_select ".class-trip-participants-panel form[action='#{trip_class_signup_path(trip)}'][method='post'] button", text: "I've Signed Up"
    assert_select ".class-trip-participants-panel", text: /This indicates to other Cragmont participants you have signed up/
    assert_select ".class-trip-participants-panel", text: /You must signup on Vertical World Guides' website to be enrolled\. This does not automatically sync with their signups\./
    assert_select "button", text: "I plan to register", count: 0

    assert_difference "ClassSignup.count", 1 do
      assert_no_difference "Waiver.count" do
        assert_no_difference "CampsiteSignupPayment.count" do
          post trip_class_signup_path(trip)
        end
      end
    end

    assert_redirected_to trip_url(trip)
    assert_equal "On belay! You're marked as planning to register for this class.", flash[:notice]
    signup = ClassSignup.find_by!(trip: trip, user: users(:sam))
    assert signup.confirmed?

    assert_no_difference "ClassSignup.count" do
      post trip_class_signup_path(trip)
    end
    assert_equal "Wow, that was a whipper. You're already marked as interested in this class.", flash[:alert]

    delete trip_class_signup_path(trip)
    assert_redirected_to trip_url(trip)
    assert signup.reload.canceled?
  end

  test "public class signup blocks full class" do
    trip = create_class_trip!(participant_capacity: 1)
    ClassSignup.create!(trip: trip, user: users(:alex))
    log_in_as(users(:sam))

    assert_no_difference "ClassSignup.count" do
      post trip_class_signup_path(trip)
    end

    assert_redirected_to trip_url(trip)
    assert_equal "Wow, that was a whipper. This class is full.", flash[:alert]
  end

  test "public day trip stats show simple capacity counts" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Castle Rock Day",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 9, 19),
      status: "published",
      meeting_time: "08:30",
      meeting_location: "Castle Rock parking lot",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "If you are running late, meet us at the main wall.",
      participant_capacity: 8,
      climbing_types: [ "sport" ]
    )
    lead_signup = DayTripSignup.create!(trip: trip, user: users(:sam), climbing_abilities: [ "lead" ])
    top_rope_user = User.create!(first_name: "Tara", last_name: "Toprope", email: "tara-toprope@example.com", password: "password")
    top_rope_signup = DayTripSignup.create!(trip: trip, user: top_rope_user, climbing_abilities: [ "top_rope" ])
    top_rope_signup.day_trip_signup_minors.create!(first_name: "Mika", last_name: "Toprope", age: 12, relationship: "Child")

    get trip_url(trip)

    assert_response :success
    assert_equal 1, lead_signup.lead_count
    assert_select ".stats", text: /Signed up\s*3/
    assert_select ".stats", text: /Open Spaces\s*5/
    assert_select ".stats", text: /Total Capacity\s*8/
    assert_select ".stats", text: /Top Rope/, count: 0
    assert_select ".stats", text: /Lead/, count: 0
    assert_select ".stats", text: /Reserved Lead Spots/, count: 0
    assert_equal [ "Participant", "Climbing Skills", "Bringing Gear" ], css_select(".day-trip-participants-panel .confirmed-participants-table th").map { |header| header.text.strip }
  end

  test "public day trip signup opens from crag plan modal" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Day",
      location: "Mount Tam, CA",
      start_date: Date.new(2026, 9, 12),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      carpool_meeting_spot: "Meet at Good Earth if you want to carpool. https://www.genatural.com/",
      late_arrival_instructions: "If you are running late, head toward https://example.com/crag.",
      participant_capacity: 8,
      sun_exposure: "Afternoon sun",
      climbing_types: [ "sport", "trad" ]
    )
    log_in_as(users(:sam))

    get trip_url(trip)

    assert_response :success
    assert_select ".day-trip-signup-panel", count: 0
    assert_select ".day-trip-details-panel" do
      assert_select "h2", "Crag Plan"
      assert_select "dl.details-list", text: /Types of climbing/
      assert_select ".gear-needed-item.is-needed", text: /Sport/
      assert_select ".gear-needed-item.is-needed", text: /Trad/
      assert_select ".gear-needed-item", text: /Bouldering/
      assert_select "dl.details-list", text: /Both/, count: 0
      assert_select "dl.details-list", text: /Cost\s*Free/
      assert_select "dl.details-list", text: /Sun Exposure\s*Afternoon sun/
      assert_select "dl.details-list", text: /Carpooling info\s*Meet at Good Earth if you want to carpool\./
      assert_select "a[href='https://www.genatural.com/'][target='_blank'][rel='noopener']", text: "https://www.genatural.com/"
      assert_select "dl.details-list", text: /If you are running late\s*If you are running late, head toward/
      assert_select "a[href='https://example.com/crag'][target='_blank'][rel='noopener']", text: "https://example.com/crag"
      assert_select "dl.details-list", text: /\$0\.00/, count: 0
      assert_select ".day-trip-signup-action [data-controller='modal']" do
        assert_select "button.day-trip-signup-button[data-action='modal#open']", "Sign Up"
        assert_select "dialog.day-trip-signup-modal" do
          assert_select "h2", "Sign Up"
          assert_select "form.day-trip-signup-form[action='#{trip_day_trip_signup_path(trip)}']" do
            assert_select ".capacity-warning[hidden]", text: "This trip is currently full. You can sign up for the waitlist"
            assert_select "legend", text: /Climbing ability/
            assert_select ".signup-field-subtext", text: "Select the type of climbing you are competent at"
            assert_select ".climbing-ability-options[data-climbing-ability-group='true']"
            assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='top_rope'][data-action='signature#toggleExclusiveClimbingAbility']"
            assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='lead'][data-action='signature#toggleExclusiveClimbingAbility']"
            assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='bouldering']", count: 0
            assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='none'][data-action='signature#toggleExclusiveClimbingAbility']"
            assert_select ".climbing-ability-choice > .climbing-ability-definition", count: 0
            assert_select ".climbing-ability-card .climbing-ability-card-heading", text: /Top Rope Climbing/
            assert_select ".climbing-ability-card .climbing-ability-card-heading", text: /Lead Climbing/
            assert_select ".climbing-ability-definition", text: /I feel competent to put on my harness/
            assert_select ".climbing-ability-definition", text: /I feel competent to lead a route placing protection/
            assert_select ".climbing-ability-definition", text: /protecting with crash pads/, count: 0
            assert_select ".climbing-ability-definition", text: /We ask that at a minimum you feel competent Top Rope climbing\./
            assert_select ".climbing-ability-definition", text: /\(on roped trips\)/, count: 0
            assert_select "input[type='checkbox'][name='day_trip_signup[with_guest]']", count: 0
            assert_select "label", text: /Add one adult/, count: 0
            assert_select ".guest-fields", count: 0
            assert_select "input[type='checkbox'][name='day_trip_signup[with_minor]'][value='1']"
            assert_select ".minor-fields .day-trip-minor-field-row" do
              assert_select "input[name='day_trip_signup[day_trip_signup_minors_attributes][0][first_name]']"
              assert_select "input[name='day_trip_signup[day_trip_signup_minors_attributes][0][last_name]']"
              assert_select "input[name='day_trip_signup[day_trip_signup_minors_attributes][0][age]']"
              assert_select "input[name='day_trip_signup[day_trip_signup_minors_attributes][0][relationship]']"
            end
            assert_select "legend", text: "Gear I plan to bring"
            assert_select "input[type='checkbox'][name='day_trip_signup[rope_60m]'][value='1']"
            assert_select "input[type='checkbox'][name='day_trip_signup[rope_70m]'][value='1']"
            assert_select "input[type='checkbox'][name='day_trip_signup[quickdraws_and_sport_anchor]'][value='1']"
            assert_select "input[type='checkbox'][name='day_trip_signup[clip_stick]'][value='1']"
            assert_select "input[type='checkbox'][name='day_trip_signup[cams_nuts_and_trad_anchor]'][value='1']"
            assert_select "input[name='day_trip_signup[crash_pad_count]']", count: 0
          end
        end
      end
    end
  end

  test "public day trip signup button points to waitlist when trip is full" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Full Vent 5",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 1,
      climbing_types: [ "sport" ]
    )
    signed_up_user = User.create!(first_name: "Fiona", last_name: "Full", email: "fiona-full@example.com", password: "password")
    DayTripSignup.create!(trip: trip, user: signed_up_user, climbing_abilities: [ "top_rope" ])
    log_in_as(users(:sam))

    get trip_url(trip)

    assert_response :success
    assert_select ".day-trip-signup-button.is-waitlist", text: "Sign up for waitlist"
    assert_select "form.day-trip-signup-form[data-signature-waitlist-skips-waiver-value='false']"
  end

  test "public day trip waitlist signup requires waiver when no annual waiver exists" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Waitlist Vent 5",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 1,
      climbing_types: [ "sport" ]
    )
    signed_up_user = User.create!(first_name: "Fiona", last_name: "Full", email: "fiona-full-waitlist@example.com", password: "password")
    DayTripSignup.create!(trip: trip, user: signed_up_user, climbing_abilities: [ "top_rope" ])
    log_in_as(users(:sam))

    assert_no_difference "DayTripSignup.count" do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "lead" ],
          rope_60m: "1",
          quickdraws_and_sport_anchor: "1"
        }
      }
    end

    assert_redirected_to trip_url(trip)
    assert_equal "Please agree to the waiver acknowledgement before tying in.", flash[:alert]
  end

  test "public day trip signup joins waitlist with signed waiver when trip is full" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Waitlist Vent 5 Signed",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 1,
      climbing_types: [ "sport" ]
    )
    signed_up_user = User.create!(first_name: "Fiona", last_name: "Full", email: "fiona-full-waitlist-signed@example.com", password: "password")
    DayTripSignup.create!(trip: trip, user: signed_up_user, climbing_abilities: [ "top_rope" ])
    log_in_as(users(:sam))

    assert_difference [ "DayTripSignup.count", "Waiver.count" ], 1 do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "lead" ],
          rope_60m: "1",
          quickdraws_and_sport_anchor: "1",
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    assert_redirected_to trip_url(trip)
    assert_equal "On belay! You're on the waitlist for this day trip.", flash[:notice]
    signup = DayTripSignup.find_by!(trip: trip, user: users(:sam))
    assert signup.waitlisted?
    assert_equal [ "lead" ], signup.climbing_abilities
    assert signup.rope_60m?
    assert signup.quickdraws_and_sport_anchor?
    assert signup.waiver_signed?
    assert signup.waiver_signed_at.present?
    assert users(:sam).current_waiver_for_year(2026).present?
  end

  test "public day trip waitlist signup accepts existing annual waiver" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Waitlist Vent 5 Annual Waiver",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 1,
      climbing_types: [ "sport" ]
    )
    signed_up_user = User.create!(first_name: "Fiona", last_name: "Full", email: "fiona-full-waitlist-annual@example.com", password: "password")
    DayTripSignup.create!(trip: trip, user: signed_up_user, climbing_abilities: [ "top_rope" ])
    WaiverCreator.new(
      user: users(:sam),
      signature: WaiverSignatureData.new(SIGNATURE_DATA_URL),
      acknowledged_at: Time.current,
      request: ActionDispatch::TestRequest.create,
      waiver_year: trip.start_date.year
    ).create!
    log_in_as(users(:sam))

    assert_difference "DayTripSignup.count", 1 do
      assert_no_difference "Waiver.count" do
        post trip_day_trip_signup_path(trip), params: {
          day_trip_signup: {
            climbing_abilities: [ "lead" ],
            rope_60m: "1"
          }
        }
      end
    end

    assert_redirected_to trip_url(trip)
    signup = DayTripSignup.find_by!(trip: trip, user: users(:sam))
    assert signup.waitlisted?
    assert signup.waiver_signed?
  end

  test "public day trip detail shows waitlisted participants separately" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Waitlist",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 1,
      climbing_types: [ "sport" ]
    )
    confirmed_user = User.create!(first_name: "Fiona", last_name: "Full", email: "fiona-day-confirmed@example.com", password: "password")
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa-day-wait@example.com", password: "password")
    DayTripSignup.create!(trip: trip, user: confirmed_user, climbing_abilities: [ "top_rope" ])
    DayTripSignup.create!(trip: trip, user: waitlisted_user, climbing_abilities: [ "lead" ], status: "waitlisted")

    get trip_url(trip)

    assert_response :success
    assert_select ".day-trip-participants-panel:first-of-type" do
      assert_select "h2", "Participants"
      assert_select "td", text: "Fiona F."
      assert_select "td", text: "Willa W.", count: 0
    end
    assert_select ".day-trip-waitlist-panel" do
      assert_select "h2", "Trip waitlist"
      assert_select "th", text: "Priority", count: 0
      assert_select "th", text: "Participant"
      assert_select "th", text: "Climbing Skills"
      assert_select "th", text: "Bringing Gear"
      assert_select "td", text: "Willa W."
      assert_select "td", text: "Lead"
      assert_select "td", text: "Fiona F.", count: 0
    end
  end

  test "public day trip safety reminder uses editable markdown setting" do
    SiteSetting.current.update!(day_trip_safety_reminder: "## Belay Check\n\nBring **judgment** to the crag.")
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Safety",
      location: "Marin Coast",
      start_date: Date.new(2026, 9, 13),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 8,
      climbing_types: [ "sport" ]
    )

    get trip_url(trip)

    assert_response :success
    assert_select ".day-trip-safety-panel .content-page-markdown h2", "Belay Check"
    assert_select ".day-trip-safety-panel .content-page-markdown strong", "judgment"
  end

  test "public day trip signup accepts multiple climbing abilities" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Boulder Bash",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 9, 26),
      status: "published",
      meeting_time: "09:00",
      meeting_location: "Castle Rock parking lot",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "Meet us by the main boulders.",
      participant_capacity: 4,
      climbing_types: [ "bouldering" ]
    )
    log_in_as(users(:sam))

    get trip_url(trip)

    assert_response :success
    assert_select "form.day-trip-signup-form[action='#{trip_day_trip_signup_path(trip)}']" do
      assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='top_rope']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='lead']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='bouldering']"
      assert_select "input[type='checkbox'][name='day_trip_signup[climbing_abilities][]'][value='none'][data-action='signature#toggleExclusiveClimbingAbility']"
      assert_select ".climbing-ability-definition", text: /We ask that at a minimum you feel competent assessing falls and protecting landing areas\./
      assert_select ".climbing-ability-definition", text: /We ask that at a minimum you feel competent Top Rope climbing\./, count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[with_guest]']", count: 0
      assert_select ".guest-fields", count: 0
      assert_select "legend", text: "Gear I plan to bring"
      assert_select "input[type='checkbox'][name='day_trip_signup[rope_60m]']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[rope_70m]']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[quickdraws_and_sport_anchor]']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[clip_stick]']", count: 0
      assert_select "input[type='checkbox'][name='day_trip_signup[cams_nuts_and_trad_anchor]']", count: 0
      assert_select "input[type='number'][name='day_trip_signup[crash_pad_count]']"
      assert_select "label", text: /Crash Pad/
      assert_select "label", text: /How many/
    end

    assert_difference "DayTripSignup.count", 1 do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "top_rope", "bouldering", "none" ],
          rope_60m: "1",
          rope_70m: "1",
          quickdraws_and_sport_anchor: "1",
          cams_nuts_and_trad_anchor: "1",
          crash_pad_count: "2",
          with_guest: "1",
          guest_attributes: {
            "0" => {
              first_name: "Blake",
              last_name: "Boulder",
              email: "blake-boulder@example.com",
              phone: "555-0188",
              climbing_abilities: [ "lead", "bouldering" ]
            }
          },
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    assert_redirected_to trip_url(trip)
    signup = DayTripSignup.find_by!(trip: trip, user: users(:sam))
    assert_equal [ "bouldering" ], signup.climbing_abilities
    assert_equal "Bouldering", signup.skill_level_label
    assert_not signup.rope_60m?
    assert_not signup.rope_70m?
    assert_not signup.quickdraws_and_sport_anchor?
    assert_not signup.cams_nuts_and_trad_anchor?
    assert_equal 2, signup.crash_pad_count
    assert_equal "Crash pads (2)", signup.shared_gear_summary
    assert_empty signup.guest_signups
  end

  test "public day trip signup does not save none with roped climbing abilities" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Skills",
      location: "Marin Coast",
      start_date: Date.new(2026, 10, 3),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 4,
      climbing_types: [ "sport" ]
    )
    log_in_as(users(:sam))

    assert_difference "DayTripSignup.count", 1 do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "top_rope", "lead", "none" ],
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    signup = DayTripSignup.find_by!(trip: trip, user: users(:sam))
    assert_equal [ "top_rope", "lead" ], signup.climbing_abilities
    assert_equal "Top rope and Lead", signup.skill_level_label
  end

  test "public roped day trip signup rejects none by itself" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Vent 5 Intro",
      location: "Marin Coast",
      start_date: Date.new(2026, 10, 4),
      status: "published",
      meeting_time: "07:00",
      meeting_location: "Vent 5 Parking Trailhead",
      meeting_location_url: "https://maps.google.com/?q=Vent+5",
      late_arrival_instructions: "If you are running late, head toward the crag.",
      participant_capacity: 4,
      climbing_types: [ "sport" ]
    )
    log_in_as(users(:sam))

    assert_no_difference "DayTripSignup.count" do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "none" ],
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    assert_redirected_to trip_url(trip)
    assert_equal "Choose an available climbing ability before tying in.", flash[:alert]
  end

  test "public bouldering day trip signup rejects none by itself" do
    trip = Trip.create!(
      trip_type: "day_trip",
      name: "Boulder Basics",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 10, 10),
      status: "published",
      meeting_time: "09:00",
      meeting_location: "Castle Rock parking lot",
      meeting_location_url: "https://maps.google.com/?q=Castle+Rock",
      late_arrival_instructions: "Meet us by the main boulders.",
      participant_capacity: 4,
      climbing_types: [ "bouldering" ]
    )
    log_in_as(users(:sam))

    assert_no_difference "DayTripSignup.count" do
      post trip_day_trip_signup_path(trip), params: {
        day_trip_signup: {
          climbing_abilities: [ "none" ],
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    assert_redirected_to trip_url(trip)
    assert_equal "Choose an available climbing ability before tying in.", flash[:alert]
  end

  test "camping trip what to expect page renders editable content page copy" do
    ContentPage.current!("what_to_expect").update!(
      title: "Custom what to expect",
      subtitle: "Custom subtitle.",
      body: "## Custom heading\n\nCustom **body** copy."
    )

    get what_to_expect_trips_url

    assert_response :success
    assert_select "h1", "Custom what to expect"
    assert_select ".panel-header .muted", "Custom subtitle."
    assert_select ".content-page-markdown h2", "Custom heading"
    assert_select ".content-page-markdown strong", "body"
  end

  test "day trip what to expect page renders editable content page copy" do
    ContentPage.current!("day_trip_what_to_expect").update!(
      title: "Custom day trip what to expect",
      subtitle: "Custom day trip subtitle.",
      body: "## Custom day trip heading\n\nCustom **day trip** copy."
    )

    get day_trip_what_to_expect_trips_url

    assert_response :success
    assert_select "h1", "Custom day trip what to expect"
    assert_select ".panel-header .muted", "Custom day trip subtitle."
    assert_select ".content-page-markdown h2", "Custom day trip heading"
    assert_select ".content-page-markdown strong", "day trip"
  end

  test "liability warning appears on public trip pages" do
    SiteSetting.current.update!(liability_warning: "Custom liability warning for public pages.")

    get root_url

    assert_response :success
    assert_select ".public-liability-warning", text: /Custom liability warning for public pages/

    get trips_url

    assert_response :success
    assert_select ".public-liability-warning", text: /Custom liability warning for public pages/

    get past_trips_trips_url

    assert_response :success
    assert_select ".public-liability-warning", text: /Custom liability warning for public pages/

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".public-liability-warning", text: /Custom liability warning for public pages/
  end

  test "past trips page shows archived trips five at a time" do
    archived_trips = 6.times.map do |index|
      Trip.create!(
        name: "Archived Route #{index + 1}",
        location: "Archive Wall, CA",
        start_date: Date.new(2025, 1, index + 1),
        end_date: Date.new(2025, 1, index + 2),
        status: "archived"
      )
    end

    get trips_url

    assert_response :success
    assert_select ".archived-trips-panel", count: 0
    archived_trips.each do |trip|
      assert_select ".archived-trip-row[href='#{trip_path(trip)}']", count: 0
    end

    get past_trips_trips_url

    assert_response :success
    assert_select ".archived-trips-panel" do
      assert_select "h1", "Past Trips"
      assert_select "a[href='#{trips_path}']", text: "Current Trips"
      archived_trips[1..5].each do |trip|
        assert_select ".archived-trip-row[href='#{trip_path(trip)}'] h3", text: trip.name
      end
      assert_select ".archived-trip-row[href='#{trip_path(archived_trips.first)}']", count: 0
      assert_select ".pagination-summary", "Page 1 of 2"
      assert_select "a[href='#{past_trips_trips_path(archived_page: 2, anchor: "archived-trips")}']", text: "Next"
    end

    get past_trips_trips_url(archived_page: 2)

    assert_response :success
    assert_select ".archived-trips-panel" do
      assert_select ".archived-trip-row[href='#{trip_path(archived_trips.first)}'] h3", text: archived_trips.first.name
      archived_trips[1..5].each do |trip|
        assert_select ".archived-trip-row[href='#{trip_path(trip)}']", count: 0
      end
      assert_select ".pagination-summary", "Page 2 of 2"
      assert_select "a[href='#{past_trips_trips_path(archived_page: 1, anchor: "archived-trips")}']", text: "Previous"
    end
  end

  test "trips index hides admin link from signed in users without admin access" do
    log_in_as(users(:sam))

    get trips_url

    assert_response :success
    assert_select "a.public-admin-link", text: "Admin", count: 0
  end

  test "trips index shows admin link to users with admin access" do
    log_in_as(users(:alex))

    get trips_url

    assert_response :success
    assert_select "a.public-admin-link[href='#{admin_root_path}']", text: "Admin"
  end

  test "public pages hide deleted trips" do
    trips(:yosemite).soft_delete!

    get trips_url

    assert_response :success
    assert_select "a", text: "Yosemite Valley Spring", count: 0

    get trip_url(trips(:yosemite))

    assert_response :not_found

    log_in_as(users(:sam))
    post signup_url_for

    assert_response :not_found
  end

  test "public trip detail shows trip campsite and coordinator info" do
    trips(:yosemite).update!(
      description: "**Yosemite** camping notes.\n\n## Parking\n\nArrive early and bring snacks.",
      whatsapp_group: "https://chat.whatsapp.com/yosemite-spring",
      weather_url: "https://forecast.weather.gov/yosemite-spring",
      photo_album_url: "https://photos.app.goo.gl/yosemite-spring"
    )

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Yosemite Valley Spring"
    assert_select "h2", "Yosemite Valley, CA"
    assert_select ".background-image-caption", "IRS Wall, Joshua Tree"
    assert_select ".trip-show-mobile-hero .trip-type-badge", text: "Camping Trip"
    assert_select ".trip-show-mobile-hero .trip-whatsapp-mobile-link[href='https://chat.whatsapp.com/yosemite-spring'][target='_blank'][rel='noopener']", text: "Join the WhatsApp Group"
    assert_select ".trip-show-mobile-hero .trip-weather-mobile-link[href='https://forecast.weather.gov/yosemite-spring'][target='_blank'][rel='noopener']", text: "Weather"
    assert_select ".trip-show-mobile-hero .trip-photo-album-mobile-link[href='https://photos.app.goo.gl/yosemite-spring'][target='_blank'][rel='noopener']", text: "Photo Album"
    assert_select ".trip-summary-notices a.trip-whatsapp-link[href='https://chat.whatsapp.com/yosemite-spring'][target='_blank'][rel='noopener']", text: "Join the WhatsApp Group"
    assert_select ".trip-summary-notices a.trip-weather-link[href='https://forecast.weather.gov/yosemite-spring'][target='_blank'][rel='noopener']", text: "Weather"
    assert_select ".trip-summary-notices a.trip-photo-album-link[href='https://photos.app.goo.gl/yosemite-spring'][target='_blank'][rel='noopener']", text: "Photo Album"
    assert_select ".trip-summary-header .trips-faq-callout", text: /camping trip/
    assert_select ".trip-summary-header .trips-faq-callout a[href='#{what_to_expect_trips_path}']", text: "here."
    assert_select ".trip-summary-header .site-feedback-callout a[href='#{new_help_request_path}']", text: "let us know."
    assert_select ".trip-overview .description", text: /Notes:/
    assert_select ".trip-overview .description .content-page-markdown strong", text: "Yosemite"
    assert_select ".trip-overview .description .content-page-markdown h2", text: "Parking"
    assert_no_match(/\*\*Yosemite\*\*/, response.body)
    assert_no_match(/## Parking/, response.body)
    assert_select "h2", "Trip Coordinator"
    assert_select ".details-list", text: /Alex Rivera/
    assert_select ".details-list", text: /alex@example.com/
    assert_select ".details-list", text: /555-0100/, count: 0
    assert_select ".stats", text: /Signed up/
    assert_select ".stats", text: /Open Spaces/
    assert_select ".stats", text: /Total Capacity/
    assert_select ".stats .success-stat", text: /10/
    assert_select ".stats .success-stat", text: /Open Spaces/
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Upper Pines/
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /site A12/
    assert_select "#campsite-#{campsites(:yosemite_a).id} .parking-stat" do
      assert_select "> span", text: "Parking"
      assert_select "> .parking-tooltip", count: 0
      assert_select ".parking-breakdown-item", text: /Assigned/
      assert_select ".parking-breakdown-item", text: /Open/
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .campsite-stats", text: /Cars/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Close to bathrooms/
  end

  test "climbing partner board signup is separate from campsite signup" do
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "form[action='#{signup_path_for}']" do
      assert_select "input[name='campsite_signup[needs_climbing_partner]']", count: 0
    end
    assert_select "#climbing-partners" do
      assert_select "p", text: /does not sign you up for the trip/
      assert_select "form[action='#{trip_climbing_partner_request_path(trips(:yosemite))}'][method='post']" do
        assert_select "button", "Add me to the board"
      end
      assert_select ".climbing-partner-self-service", text: /no campsite signup, dates, waiver, or payment required/
    end
  end

  test "public climbing partner board shows trip level requests without requiring a campsite signup" do
    partner_user = User.create!(first_name: "Pia", last_name: "Partner", email: "pia-partner@example.com", phone: "555-0199", password: "password")
    private_user = User.create!(first_name: "Nora", last_name: "NotLooking", email: "nora-private@example.com", password: "password")
    other_trip_user = User.create!(first_name: "Joshua", last_name: "Tree", email: "joshua-trip@example.com", password: "password")
    ClimbingPartnerRequest.create!(trip: trips(:yosemite), user: partner_user)
    ClimbingPartnerRequest.create!(trip: trips(:jtree), user: other_trip_user)

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_nil CampsiteSignup.find_by(user: partner_user)
    assert_operator response.body.index("campsites-panel"), :<, response.body.index("climbing-partners")
    assert_select "#climbing-partners" do
      assert_select "h2", "Climbing Partner Board"
      assert_select ".climbing-partner-card", count: 1 do
        assert_select "strong", "Pia P."
        assert_select "button", "Show contact info"
        assert_select "a[href^='mailto:']", count: 0
        assert_select "dialog.climbing-partner-contact-modal" do
          assert_select "h2", "Pia P. contact info"
          assert_select ".climbing-partner-contact-details", text: /555-0199/
          assert_select ".climbing-partner-contact-details", text: /pia-partner@example.com/
        end
        assert_select ".climbing-partner-details", text: /Looking for a climbing partner on this trip/
      end
      assert_select ".climbing-partner-privacy-note", count: 0
      assert_select "a[href='mailto:nora-private@example.com']", count: 0
      assert_select "a[href='mailto:joshua-trip@example.com']", count: 0
    end
  end

  test "archived public trip detail is viewable but closed to new participants" do
    trips(:yosemite).update!(status: "archived")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Yosemite Valley Spring"
    assert_select ".campsite-signup-action", text: /Archived trip/
    assert_select "button", text: "Sign up for this campsite", count: 0
    assert_select "button", text: "Join waitlist", count: 0
    assert_select "a", text: "Log in to sign up", count: 0

    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: waiver_signature_params
    end

    assert_response :not_found
  end

  test "public trip detail shows placeholder when campsite coordinator is not set" do
    trips(:yosemite).update!(campsite_coordinator: nil)

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "h2", "Trip Coordinator"
    assert_select "section.panel", text: /Not yet set/
    assert_select ".details-list", text: /Alex Rivera/, count: 0
    assert_select ".details-list", text: /555-0100/, count: 0
  end

  test "public cancellation modal shows refund policy details" do
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
      log_in_as(users(:sam))

      get trip_url(trips(:yosemite))

      assert_response :success
      assert_select "dialog.signup-modal" do
        assert_select "h2", "Remove yourself from this campsite?"
        assert_select ".cancellation-policy-details", text: /Cancelation policy:\s*Full refund if 7 or more days before start of trip/
        assert_select ".cancellation-policy-details dt", "Trip starts"
        assert_select ".cancellation-policy-details dd", "June 12, 2026"
        assert_select ".cancellation-policy-details dt", "Days until trip"
        assert_select ".cancellation-policy-details dd", "7"
        assert_select ".cancellation-policy-details dt", "Refund amount"
        assert_select ".cancellation-policy-details dd", "$40.00"
      end
    end
  end

  test "logged out signup redirects to login" do
    post signup_url_for

    assert_redirected_to new_session_url
  end

  test "user can register" do
    assert_difference "User.count", 1 do
      post registration_url, params: {
        user: {
          first_name: "Mina",
          last_name: "Park",
          email: "mina@example.com",
          phone: "555-0200",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to trips_url
    assert_not User.order(:created_at).last.member?
  end

  test "registration with existing email links to password reset" do
    assert_no_difference "User.count" do
      post registration_url, params: {
        user: {
          first_name: "Alex",
          last_name: "Rivera",
          email: "ALEX@example.com",
          phone: "555-0200",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".registration-existing-account-alert" do
      assert_select "h2", "You already have a Cragmont account"
      assert_select "p", text: /That email address is already connected to an account/
      assert_select "a[href='#{new_password_reset_path}']", "Password Reset"
    end
    assert_select ".form-errors", text: /Email has already been taken/, count: 0
    assert_select "input[type='email'][name='user[email]'][value='ALEX@example.com']"
  end

  test "registration form has password visibility controls" do
    get new_registration_url

    assert_response :success
    assert_select "body.registration-new-page"
    assert_select ".background-image-caption", "Tuolumne Meadows, Cathedral Peak"
    assert_select ".password-visibility-field[data-controller='password-visibility']", count: 2
    assert_select "button.password-visibility-toggle[aria-label='Show password']", count: 2
    assert_select "input[type='password'][data-password-visibility-target='input']", count: 2
  end

  test "user can log in and log out" do
    post session_url, params: { email: "ALEX@EXAMPLE.COM", password: "password" }

    assert_redirected_to trips_url

    delete session_url

    assert_redirected_to root_url
  end

  test "logged in user can sign up for a campsite" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    signup = CampsiteSignup.find_by(trip: trips(:yosemite), user: users(:sam))
    assert_equal campsites(:yosemite_a), signup.campsite
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
    assert_equal 2, signup.night_count
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert signup.waiver_signature_image.attached?
    assert signup.waiver_document.attached?
    assert_match(/\A\d{4}-\d{2}-\d{2}-Sam-Lee-Yosemite-Valley-Spring-A12-#{signup.id}\.pdf\z/, signup.waiver_document.filename.to_s)
    assert_equal users(:sam).full_name, signup.waiver_signer_name
    assert signup.waiver_acknowledged_at.present?
    assert_equal TripSignupWaiver.acknowledgement_text, signup.waiver_acknowledgement_text
    assert_equal TripSignupWaiver.text, signup.waiver_text
  end

  test "non-participant can add and remove a climbing partner request without waiver dates or payment" do
    log_in_as(users(:sam))
    request_path = trip_climbing_partner_request_path(trips(:yosemite))

    assert_difference "ClimbingPartnerRequest.count", 1 do
      assert_no_difference [ "CampsiteSignup.count", "Waiver.count", "CampsiteSignupPayment.count" ] do
        post request_path
      end
    end

    assert_redirected_to trip_url(trips(:yosemite), anchor: "climbing-partners")
    partner_request = ClimbingPartnerRequest.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert_equal "On belay! You're now on the Climbing Partner Board.", flash[:notice]

    assert_difference "ClimbingPartnerRequest.count", -1 do
      delete request_path
    end

    assert_redirected_to trip_url(trips(:yosemite), anchor: "climbing-partners")
    assert_not ClimbingPartnerRequest.exists?(partner_request.id)
    assert_equal "On belay! Your climbing partner request is off the board.", flash[:notice]
  end

  test "creating the same climbing partner request twice is idempotent" do
    log_in_as(users(:sam))
    request_path = trip_climbing_partner_request_path(trips(:yosemite))

    assert_difference "ClimbingPartnerRequest.count", 1 do
      post request_path
    end
    assert_no_difference "ClimbingPartnerRequest.count" do
      post request_path
    end

    assert_redirected_to trip_url(trips(:yosemite), anchor: "climbing-partners")
    assert_equal "You're already on the Climbing Partner Board.", flash[:notice]
  end

  test "logged out visitor must log in before joining the climbing partner board" do
    assert_no_difference "ClimbingPartnerRequest.count" do
      post trip_climbing_partner_request_path(trips(:yosemite))
    end

    assert_redirected_to new_session_url
  end

  test "current annual waiver skips signature for adult only trip signup" do
    previous_signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: users(:sam))
    current_waiver = attach_test_waiver_to(previous_signup).waiver
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      assert_no_difference "Waiver.count" do
        post signup_url_for, params: {
          campsite_signup: {
            arrival_date: "2026-06-13",
            checkout_date: "2026-06-15"
          }
        }
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal current_waiver, signup.waiver
    assert signup.waiver_signed?
  end

  test "paid signup creates pending payment and confirms from Stripe webhook" do
    SiteSetting.current.update!(first_two_nights_fee: "50", extra_night_fee: "10")
    log_in_as(users(:sam))

    with_fake_stripe_checkout do
      assert_difference "CampsiteSignup.count", 1 do
        assert_difference "CampsiteSignupPayment.count", 1 do
          post signup_url_for, params: waiver_signature_params
        end
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    payment = signup.current_payment
    assert_redirected_to payment.checkout_url
    assert signup.pending_payment?
    assert_equal "pending", payment.status
    assert_equal 60_00, payment.amount_cents
    assert_equal "cs_test_#{payment.id}", payment.stripe_checkout_session_id
    assert_in_delta 30.minutes.from_now.to_i, payment.expires_at.to_i, 5
    assert_in_delta payment.expires_at.to_i, payment.checkout_expires_at.to_i, 5
    assert_equal 5, campsites(:yosemite_a).reload.available_participant_capacity

    post signup_url_for, params: waiver_signature_params

    assert_redirected_to payment.checkout_url

    post stripe_webhooks_url, params: stripe_checkout_event("checkout.session.completed", payment, payment_intent: "pi_test_123"), headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :ok
    assert signup.reload.confirmed?
    assert payment.reload.paid?
    assert_equal "pi_test_123", payment.stripe_payment_intent_id
  end

  test "pending payment repeat signup refuses non Stripe checkout URL" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "pending_payment")
    signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 60_00,
      checkout_url: "https://example.com/not-stripe"
    )
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Payment checkout link is not available. Please try again.", flash[:alert]
  end

  test "expired paid signup releases pending hold" do
    SiteSetting.current.update!(first_two_nights_fee: "50")
    log_in_as(users(:sam))

    with_fake_stripe_checkout do
      post signup_url_for, params: waiver_signature_params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    payment = signup.current_payment
    assert signup.pending_payment?

    post stripe_webhooks_url, params: stripe_checkout_event("checkout.session.expired", payment), headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :ok
    assert signup.reload.canceled?
    assert payment.reload.expired?
    assert_equal 6, campsites(:yosemite_a).reload.available_participant_capacity
  end

  test "expired Stripe session keeps admin-added 30 day payment link pending" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "pending_payment")
    payment = signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 3500,
      expires_at: 30.days.from_now,
      checkout_expires_at: 1.hour.ago,
      checkout_url: "https://checkout.stripe.com/c/pay/old",
      stripe_checkout_session_id: "cs_admin_old",
      previous_signup_status: "confirmed"
    )

    post stripe_webhooks_url, params: stripe_checkout_event("checkout.session.expired", payment), headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :ok
    assert signup.reload.pending_payment?
    payment.reload
    assert payment.pending?
    assert_nil payment.checkout_url
    assert_nil payment.checkout_expires_at
    assert_nil payment.stripe_checkout_session_id
  end

  test "paid participant removal preserves canceled signup and refunds manual payment record" do
    travel_to Date.new(2026, 6, 5) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 1000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )
      log_in_as(users(:sam))

      assert_no_difference "CampsiteSignup.count" do
        delete signup_url_for
      end

      assert_redirected_to trip_url(trips(:yosemite))
      assert signup.reload.canceled?
      assert signup.current_payment.refunded?
    end
  end

  test "paid participant stripe refund records participant initiator" do
    travel_to Date.new(2026, 6, 5) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      payment = signup.payments.create!(
        source: "stripe",
        status: "paid",
        amount_cents: 1000,
        paid_at: Time.current,
        stripe_payment_intent_id: "pi_participant_cancel"
      )
      stripe_refund = Struct.new(:id, :status).new("re_participant_cancel", "succeeded")
      log_in_as(users(:sam))

      with_fake_stripe_refund(stripe_refund) do
        delete signup_url_for
      end

      refund = payment.refunds.reload.sole
      assert refund.participant_initiated_by?
      assert_equal "automatic", refund.refund_type
      assert_equal "cancellation_by_participant", refund.reason
      assert_equal "re_participant_cancel", refund.stripe_refund_id
    end
  end

  test "paid participant removal does not refund inside seven day cutoff" do
    travel_to Date.new(2026, 6, 6) do
      signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
      payment = signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 1000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )
      log_in_as(users(:sam))

      assert_no_difference "CampsiteSignup.count" do
        delete signup_url_for
      end

      assert_redirected_to trip_url(trips(:yosemite))
      assert signup.reload.canceled?
      assert payment.reload.paid?
      assert_equal 0, payment.refunded_amount_cents
    end
  end

  test "paid participant can cancel after campsite dates changed outside attendance dates" do
    travel_to Date.new(2026, 6, 5) do
      campsite = campsites(:yosemite_a)
      signup = create_campsite_signup!(campsite: campsite, user: users(:sam))
      signup.payments.create!(
        source: "manual",
        status: "paid",
        amount_cents: 1000,
        manual_payment_method: "cash",
        manual_paid_at: Time.current,
        paid_at: Time.current
      )
      campsite.update_columns(arrival_date: campsite.arrival_date + 1.day, updated_at: Time.current)
      log_in_as(users(:sam))

      assert_no_difference "CampsiteSignup.count" do
        delete signup_url_for
      end

      assert_redirected_to trip_url(trips(:yosemite))
      assert signup.reload.canceled?
      assert signup.current_payment.refunded?
    end
  end

  test "paid participant can sign up again after canceling" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 1000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      delete signup_url_for
    end
    assert signup.reload.canceled?

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for(campsites(:yosemite_b)), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    new_signup = CampsiteSignup.where(trip: trips(:yosemite), user: users(:sam)).order(:created_at).last
    assert new_signup.confirmed?
    assert_equal campsites(:yosemite_b), new_signup.campsite
  end

  test "guest cannot remove themselves from a paid party" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "gina-paid-party@example.com",
      password: "password"
    )
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )
    primary_signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 2000,
      manual_payment_method: "cash",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    log_in_as(guest_user)

    assert_no_difference "CampsiteSignup.count" do
      delete signup_url_for
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Guests follow the primary participant signup for paid trips.", flash[:alert]
    assert guest_signup.reload.confirmed?
  end

  test "trip detail shows signed up by note instead of remove action for logged in guest" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "gina-guest-card@example.com",
      password: "password"
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )
    log_in_as(guest_user)

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".already-signed-up-note", text: "Sam Lee signed you up"
      assert_select "button", text: "Remove me from this campsite", count: 0
      assert_select "dialog.signup-modal h2", text: "Remove yourself from this campsite?", count: 0
    end
  end

  test "logged in user can sign up with minors" do
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      assert_difference "CampsiteSignupMinor.count", 2 do
        post signup_url_for, params: waiver_signature_params_with_minors(
          { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" },
          { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" }
        )
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 2, signup.campsite_signup_minors.size
    assert_includes signup.waiver_acknowledgement_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_includes signup.waiver_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert signup.waiver_document.attached?
    assert signup.waiver.trip_minor?
  end

  test "current annual waiver does not skip signing when minors are included" do
    previous_signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: users(:sam))
    attach_test_waiver_to(previous_signup)
    log_in_as(users(:sam))
    params = waiver_signature_params_with_minors(
      { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" }
    )
    params[:campsite_signup].delete(:waiver_signature_data)

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user can sign up with guests" do
    log_in_as(users(:sam))

    assert_difference "User.count", 2 do
      assert_difference "CampsiteSignup.count", 3 do
        post signup_url_for, params: waiver_signature_params_with_guests(
          { first_name: "Gina", last_name: "Guest", email: "gina-guest@example.com", phone: "555-0300" },
          { first_name: "Omar", last_name: "Guest", email: "omar-guest@example.com", phone: "" }
        )
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert signup.waiver_signed?
    assert_equal 2, signup.guest_signups.size
    assert_equal 3, signup.party_capacity_count
    signup.guest_signups.each do |guest_signup|
      assert guest_signup.confirmed?
      assert_equal signup, guest_signup.guest_of_signup
      assert_equal signup.campsite, guest_signup.campsite
      assert_equal signup.arrival_date, guest_signup.arrival_date
      assert_equal signup.checkout_date, guest_signup.checkout_date
      assert guest_signup.user.default_password?
      assert_not guest_signup.user.authenticate(User::DEFAULT_GUEST_PASSWORD)
      assert_not guest_signup.waiver_signed?
    end
  end

  test "guest signup reuses existing user email without resetting password" do
    existing_guest = User.create!(
      first_name: "Existing",
      last_name: "Guest",
      email: "existing-guest@example.com",
      phone: "555-0302",
      password: "custom-password",
      member: true
    )
    log_in_as(users(:sam))

    assert_no_difference "User.count" do
      assert_difference "CampsiteSignup.count", 2 do
        post signup_url_for, params: waiver_signature_params_with_guests(
          { first_name: "Changed", last_name: "Name", email: "EXISTING-GUEST@example.com", phone: "555-9999" }
        )
      end
    end

    guest_signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: existing_guest)
    assert guest_signup.guest?
    assert existing_guest.reload.authenticate("custom-password")
    assert_not existing_guest.default_password?
    assert_equal "Existing", existing_guest.first_name
    assert_equal "555-0302", existing_guest.phone
    assert existing_guest.member?
  end

  test "logged in user can sign up with minors and guests" do
    log_in_as(users(:sam))

    assert_difference "User.count", 1 do
      assert_difference "CampsiteSignup.count", 2 do
        assert_difference "CampsiteSignupMinor.count", 1 do
          post signup_url_for, params: waiver_signature_params_with_minors_and_guests(
            [ { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" } ],
            [ { first_name: "Gina", last_name: "Guest", email: "minor-party-guest@example.com", phone: "555-0301" } ]
          )
        end
      end
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 1, signup.campsite_signup_minors.size
    assert_equal 1, signup.guest_signups.size
    assert_equal 2, signup.party_capacity_count
  end

  test "signup with minors requires minor information" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please enter minor information before signing up.", flash[:alert]
  end

  test "signup with minors rejects incomplete minor information" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "", age: 12, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "signup with minors rejects more than two minors" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" },
        { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" },
        { first_name: "Tali", last_name: "Lee", age: 10, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "signup with minors rejects adult age" do
    log_in_as(users(:sam))

    assert_no_difference [ "CampsiteSignup.count", "CampsiteSignupMinor.count" ] do
      post signup_url_for, params: waiver_signature_params_with_minors(
        { first_name: "Mika", last_name: "Lee", age: 18, relationship: "Child" }
      )
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "logged in user cannot sign up without signing waiver" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_acknowledged_at: Time.current.iso8601 } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up without agreeing to acknowledgement" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_signature_data: SIGNATURE_DATA_URL } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please agree to the waiver acknowledgement before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up with malformed signature" do
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: { campsite_signup: { waiver_signature_data: "not-a-signature", waiver_acknowledged_at: Time.current.iso8601 } }
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Please sign the waiver before signing up.", flash[:alert]
  end

  test "logged in user cannot sign up without attendance dates" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup].delete(:arrival_date)
    params[:campsite_signup].delete(:checkout_date)

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_match(/Arrival date can't be blank/, flash[:alert])
    assert_match(/Checkout date can't be blank/, flash[:alert])
  end

  test "logged in user cannot sign up with attendance dates outside campsite dates" do
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:arrival_date] = "2026-06-11"
    params[:campsite_signup][:checkout_date] = "2026-06-16"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for, params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_match(/Arrival date must be on or after the campsite arrival date/, flash[:alert])
    assert_match(/Checkout date must be on or before the campsite checkout date/, flash[:alert])
  end

  test "duplicate signup for another campsite in the same trip is blocked" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsites(:yosemite_b)), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
  end

  test "confirmed user can remove themself from a campsite" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", -1 do
      delete signup_url_for
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil CampsiteSignup.find_by(id: signup.id)
  end

  test "waitlisted user can remove themself from a campsite" do
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", -1 do
      delete signup_url_for
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_nil CampsiteSignup.find_by(id: signup.id)
  end

  test "trip detail shows remove modal for signed in participant" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "button", text: "Remove me from this campsite"
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /Jun 13-Jun 15/
    assert_select "dialog.signup-modal h2", text: "Remove yourself from this campsite?"
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Remove me from this campsite/
  end

  test "trip detail opens payment success modal after Stripe return" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "confirmed")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite), stripe_checkout: "success")

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true'][data-modal-disable-autofocus-value='true'] dialog.payment-success-modal" do
      assert_select "h2", "Get stoked!"
      assert_select "p", text: /Your trip to Yosemite Valley Spring is confirmed\./
      assert_select "p", text: /We'll be sending you more info as the date gets closer\./
      assert_select "p", text: /If you need to cancel, make sure to do it at least seven days before the start of the trip for a refund\./
    end
  end

  test "trip detail payment success modal lists adult guest waiver links when waivers are missing" do
    ActionMailer::Base.deliveries.clear
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "confirmed")
    david = User.create!(
      first_name: "David",
      last_name: "Ladowitz",
      email: "payment-success-david@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    zinnia = User.create!(
      first_name: "Zinnia",
      last_name: "Gray",
      email: "payment-success-zinnia@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    david_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: david,
      guest_of_signup: primary_signup,
      guest_position: 1,
      status: "confirmed"
    )
    zinnia_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: zinnia,
      guest_of_signup: primary_signup,
      guest_position: 2,
      status: "confirmed"
    )
    david_link = trip_path(trips(:yosemite), complete_signup: david_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    zinnia_link = trip_path(trips(:yosemite), complete_signup: zinnia_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    david_url = trip_url(trips(:yosemite), complete_signup: david_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    zinnia_url = trip_url(trips(:yosemite), complete_signup: zinnia_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    log_in_as(users(:sam))

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      get trip_url(trips(:yosemite), stripe_checkout: "success")
    end

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true'][data-modal-disable-autofocus-value='true'] dialog.payment-success-modal" do
      assert_select "h2", "You're not on Belay yet!"
      assert_select "p", text: /Thank you for paying!/
      assert_select "p", text: /We still need the other adults in your party to sign the waiver before you are confirmed\./
      assert_select "p", text: /Send them these links to sign in and then climb on!/
      assert_select "li", text: /David Ladowitz:/ do
        links = css_select("a").map { |link| [ link.text.squish, link["href"] ] }
        assert_includes links, [ "Waiver Link", david_link ]
        assert_select "button.copy-link-button[data-action='copy-link#copy']", text: "Copy Link"
        assert_select "[data-controller='copy-link'][data-copy-link-url-value='#{david_url}']"
        assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", trip_guest_waiver_email_path(trips(:yosemite), david_signup), text: "Email link to guest"
      end
      assert_select "li", text: /Zinnia Gray:/ do
        links = css_select("a").map { |link| [ link.text.squish, link["href"] ] }
        assert_includes links, [ "Waiver Link", zinnia_link ]
        assert_select "button.copy-link-button[data-action='copy-link#copy']", text: "Copy Link"
        assert_select "[data-controller='copy-link'][data-copy-link-url-value='#{zinnia_url}']"
        assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", trip_guest_waiver_email_path(trips(:yosemite), zinnia_signup), text: "Email link to guest"
      end
    end

    assert_empty ActionMailer::Base.deliveries
  end

  test "payment success modal does not list adult guests with current annual waiver" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "confirmed")
    guest = User.create!(
      first_name: "Gina",
      last_name: "Ready",
      email: "payment-success-ready-guest@example.com",
      password: "password"
    )
    previous_signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: guest)
    attach_test_waiver_to(previous_signup)
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest,
      guest_of_signup: primary_signup,
      guest_position: 1,
      status: "confirmed"
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite), stripe_checkout: "success")

    assert_response :success
    assert_select "dialog.payment-success-modal" do
      assert_select "h2", "Get stoked!"
      assert_select "p", text: /We still need the other adults/, count: 0
      assert_select "li", text: /Gina Ready/, count: 0
    end
  end

  test "primary participant can email guest waiver link from modal action" do
    ActionMailer::Base.deliveries.clear
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "confirmed")
    guest = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "participant-email-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest,
      guest_of_signup: primary_signup,
      guest_position: 1,
      status: "confirmed"
    )
    guest_link = trip_url(trips(:yosemite), complete_signup: guest_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    log_in_as(users(:sam))

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post trip_guest_waiver_email_url(trips(:yosemite), guest_signup)
    end

    assert_redirected_to trip_url(trips(:yosemite), anchor: "campsite-#{campsites(:yosemite_a).id}")
    assert_equal "On belay! The waiver link was emailed to Gina Guest.", flash[:notice]

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "participant-email-guest@example.com" ], mail.to
    assert_match "Sam Lee added you to the upcoming Cragmont trip.", mail.text_part.body.decoded
    assert_match "Before tying in you'll need to sign the waiver.", mail.text_part.body.decoded
    assert_match "You can do that here: #{guest_link}", mail.text_part.body.decoded
  end

  test "guest waiver email action supports in-modal json response" do
    ActionMailer::Base.deliveries.clear
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "confirmed")
    guest = User.create!(
      first_name: "Gina",
      last_name: "Json",
      email: "participant-email-json-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest,
      guest_of_signup: primary_signup,
      guest_position: 1,
      status: "confirmed"
    )
    log_in_as(users(:sam))

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post trip_guest_waiver_email_url(trips(:yosemite), guest_signup), as: :json
    end

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "Email sent", response_body.fetch("button_text")
    assert_equal "On belay! The waiver link was emailed to Gina Json.", response_body.fetch("message")
  end

  test "trip detail shows waitlist remove action in waitlist table for signed in waitlisted participant" do
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".campsite-card button", text: "Remove me from the waitlist", count: 0
    assert_select ".trip-waitlist-section button.button.danger", text: "Remove Me"
    assert_select ".trip-waitlist-section dialog.signup-modal h2", text: "Remove me from the waitlist"
    assert_select ".trip-waitlist-section form[action='#{signup_path_for}'][method='post']", text: /Remove Me/
  end

  test "trip detail shows signup modal for logged in non participant" do
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    minor_age_limit = SiteSetting.current.uncounted_minor_age_limit

    assert_response :success
    assert_select "button", text: "Sign up for this campsite"
    assert_select "dialog.signup-modal"
    assert_select ".signup-kind-options", text: /Add additional adults \(max 2\)/
    assert_select ".signup-kind-options", text: /Who are you signing up\?/, count: 0
    assert_select ".signup-kind-options", text: /Add minors \(under 18\)/
    assert_select "input[type='checkbox'][name='campsite_signup[with_minors]'][value='1']"
    assert_select "input[type='checkbox'][name='campsite_signup[with_guests]'][value='1']"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][min='2026-06-12'][max='2026-06-14']"
    assert_select "input[type='date'][name='campsite_signup[arrival_date]'][data-action*='click->signature#showDatePicker'][data-action*='focus->signature#showDatePicker']"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][min='2026-06-13'][max='2026-06-15']"
    assert_select "input[type='date'][name='campsite_signup[checkout_date]'][data-action*='click->signature#showDatePicker'][data-action*='focus->signature#showDatePicker']"
    assert_select "form.waiver-form[data-turbo='false'][data-signature-available-participant-capacity-value='6'][data-signature-show-capacity-warning-value='true'][data-signature-direct-signup-intent-value='direct_signup'][data-signature-waitlist-intent-value='join_waitlist'][data-signature-next-submit-text-value='Next'][data-signature-waitlist-submit-text-value='Join waitlist'][data-signature-first-two-nights-fee-cents-value='0'][data-signature-extra-night-fee-cents-value='0'][data-signature-minor-fee-cents-value='0'][data-signature-minor-extra-night-fee-cents-value='0']"
    assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='direct_signup'][data-signature-target='intent']"
    assert_select ".attendance-fields .payment-summary", count: 0
    assert_select ".fee-fields[data-signature-target='feeFields']" do
      assert_select ".fee-section legend", "Adult Fees"
      assert_select ".fee-section legend", "Minor Fees"
      assert_select ".payment-due-section legend", "Payment Due"
      assert_select ".refund-policy-section legend", "Refund Policy"
      assert_select ".refund-policy-section", text: /Full refund if canceled 7 or more days before trip start\./
      assert_select ".refund-policy-section", text: /No refund within seven days as it becomes hard for the club to fill the spot\./
      assert_select ".fee-rate", text: /First 2 nights.*\$0\.00/
      assert_select ".fee-rate", text: /Additional nights\s+\$0\.00/
      assert_select ".fee-rate", text: /Ages 0 to #{minor_age_limit - 1}.*Free/
      assert_select ".fee-rate", text: /Ages #{minor_age_limit} to 17.*\$0\.00/
      assert_select ".fee-rate", text: /Additional nights\s+\$0\.00/
      assert_select ".payment-line-items[data-signature-target='paymentLineItems'][hidden]"
      assert_select ".payment-summary[data-signature-target='paymentSummary']", text: /Choose dates to see payment amount/
    end
    assert_select "button[data-action='signature#continueSignup'][data-signature-target='signupStepSubmit']", text: "Next"
    assert_select ".capacity-warning[hidden]", text: /You've exceeded the space available for this campsite\. Your party will be placed on the waitlist\./, count: 2
    assert_select ".guest-fields", text: /Additional Adults\s/
    assert_select ".guest-fields .guest-field-row", count: 4
    assert_select ".guest-fields .guest-field-row[hidden]", count: 2
    assert_select ".guest-fields button.add-person-link", text: "Add another adult"
    assert_select "input[name='campsite_signup[guest_attributes][0][email]']"
    assert_select ".minor-fields", text: /Minor information\s+\(Max 2\)/
    assert_select ".minor-fields .minor-field-row", count: 4
    assert_select ".minor-fields .minor-field-row[hidden]", count: 2
    assert_select ".minor-fields button.add-person-link", text: "Add another minor"
    assert_select "button", text: "Next"
    assert_select ".waiver-intro", text: /not a teaching or instructional organization/
    assert_select "button", text: "Agree and Sign Waiver"
    assert_select ".waiver-text", text: /READ THIS DOCUMENT CAREFULLY BEFORE SIGNING/
    assert_select ".waiver-text", text: /YOU ARE GIVING UP IMPORTANT LEGAL RIGHTS/
    assert_select "canvas.signature-pad"
    assert_select "button", text: "Clear signature"
    assert_select "input[type='hidden'][name='campsite_signup[waiver_signature_data]']"
    assert_select "input[type='hidden'][name='campsite_signup[waiver_acknowledged_at]']"
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Sign Up/
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/, count: 0
  end

  test "trip detail shows paid signup modal when trip fees are configured" do
    SiteSetting.current.update!(first_two_nights_fee: "50", extra_night_fee: "10", minor_fee: "25", minor_extra_night_fee: "5")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "form.waiver-form[data-turbo='false'][data-signature-first-two-nights-fee-cents-value='5000'][data-signature-extra-night-fee-cents-value='1000'][data-signature-minor-fee-cents-value='2500'][data-signature-minor-extra-night-fee-cents-value='500'][data-signature-pay-submit-text-value='Pay Now and Sign Up'][data-signature-free-submit-text-value='Sign Up']"
    assert_select ".fee-fields" do
      assert_select ".fee-rate", text: /First 2 nights.*\$50\.00/
      assert_select ".fee-rate", text: /Additional nights\s+\$10\.00/
      assert_select ".fee-rate", text: /Ages #{SiteSetting.current.uncounted_minor_age_limit} to 17.*\$25\.00/
      assert_select ".fee-rate", text: /Additional nights\s+\$5\.00/
    end
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/
  end

  test "shared details link opens completion modal for signed in participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: nil, checkout_date: nil)
    guest_user = User.create!(
      first_name: "Jordan",
      last_name: "Guest",
      email: "jordan-completion-link@example.com",
      password: User::DEFAULT_GUEST_PASSWORD
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1,
      arrival_date: nil,
      checkout_date: nil
    )
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 17, relationship: "Child")
    signup.campsite_signup_minors.create!(first_name: "Tiny", last_name: "Lee", age: 9, relationship: "Child")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite), complete_signup: signup.signed_id(purpose: :complete_participant_details))

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true']" do
      assert_select "dialog.signup-modal"
      assert_select "h2", "You've been added to the Yosemite Valley Spring trip."
      assert_select "p", "Please select dates you will be attending"
      assert_select ".participant-details-campsite-summary", text: /Upper Pines site A12/
      assert_select ".participant-details-campsite-summary", text: /Available June 12, 2026 to June 15, 2026/
      assert_select "form[action='#{signup_path_for}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        form = css_select("form.waiver-form").sole
        assert_equal "Sam Lee", form["data-signature-primary-participant-name-value"]
        assert_equal [ "Jordan Guest" ], JSON.parse(form["data-signature-existing-adult-names-value"])
        assert_equal [ "Mika Lee" ], JSON.parse(form["data-signature-existing-counted-minor-names-value"])
        assert_equal [
          { "name" => "Mika Lee", "age" => 17 },
          { "name" => "Tiny Lee", "age" => 9 }
        ], JSON.parse(form["data-signature-existing-minor-line-items-value"])
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
        assert_select ".signup-kind-options", count: 0
        assert_select ".guest-fields", count: 0
        assert_select "button", text: "Next"
        assert_select ".waiver-intro", text: /not a teaching or instructional organization/
        assert_select "button", text: "Agree and Sign Waiver"
        assert_select ".waiver-text", text: /READ THIS DOCUMENT CAREFULLY BEFORE SIGNING/
        assert_select "canvas.signature-pad"
        assert_select "button", text: "Complete"
      end
    end
  end

  test "shared details link hides fee fields for waived payment participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: nil, checkout_date: nil)
    signup.payments.create!(
      source: "waived",
      status: "waived",
      amount_cents: 0,
      waived_reason: "Board approved comp",
      pricing_snapshot: CampsiteSignupPricing.zero.snapshot
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite), complete_signup: signup.signed_id(purpose: :complete_participant_details))

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true']" do
      assert_select "dialog.signup-modal"
      assert_select "h2", "You've been added to the Yosemite Valley Spring trip."
      assert_select "p", "Please select dates you will be attending"
      assert_select "form[action='#{signup_path_for}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
        assert_select ".fee-fields", count: 0
        assert_select ".fee-section legend", text: "Adult Fees", count: 0
        assert_select ".fee-section legend", text: "Minor Fees", count: 0
        assert_select ".payment-due-section legend", text: "Payment Due", count: 0
        assert_select ".refund-policy-section legend", text: "Refund Policy", count: 0
        assert_select "button", text: "Complete"
        assert_select "button", text: "Pay Now and Complete", count: 0
      end
    end
  end

  test "shared details link logs in waitlisted participant moved to campsite" do
    campsite = campsites(:yosemite_a)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    signup.update!(
      campsite: campsite,
      status: "confirmed",
      arrival_date: nil,
      checkout_date: nil,
      waitlist_eligible_at: nil
    )
    token = signup.signed_id(purpose: :complete_participant_details)

    get trip_url(trips(:yosemite), complete_signup: token)

    assert_response :success
    assert_select ".public-nav a[href='#{profile_path}']", text: "Sam Lee"
    assert_select ".public-nav a", text: "Log in", count: 0
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true']" do
      assert_select "dialog.signup-modal"
      assert_select "h2", "You've been added to the Yosemite Valley Spring trip."
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
        assert_select "button", text: "Complete"
      end
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    post signup_url_for(campsite), params: params

    assert_redirected_to trip_url(trips(:yosemite))
    signup.reload
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
    assert signup.waiver_signed?
  end

  test "admin-added participant can submit dates and waiver from shared details flow" do
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), arrival_date: nil, checkout_date: nil)
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Your trip details have been submitted.", flash[:notice]
    signup.reload
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
    assert signup.waiver_signed?
    assert signup.waiver_signature_image.attached?
    assert signup.waiver_document.attached?
  end

  test "admin-added paid participant gets 30 day payment link after details flow" do
    SiteSetting.current.update!(first_two_nights_fee: "35")
    campsite = campsites(:yosemite_a)
    signup = create_campsite_signup!(campsite: campsite, user: users(:sam), arrival_date: nil, checkout_date: nil)
    log_in_as(users(:sam))
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    with_fake_stripe_checkout do
      assert_difference "CampsiteSignupPayment.count", 1 do
        post signup_url_for(campsite), params: params
      end
    end

    payment = signup.reload.current_payment
    assert_redirected_to payment.checkout_url
    assert payment.pending?
    assert_in_delta 30.days.from_now.to_i, payment.expires_at.to_i, 5
    assert_in_delta 24.hours.from_now.to_i, payment.checkout_expires_at.to_i, 5
  end

  test "admin-added pending payment regenerates checkout when Stripe session expires before payment link" do
    SiteSetting.current.update!(first_two_nights_fee: "35")
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "pending_payment")
    payment = signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 3500,
      expires_at: 30.days.from_now,
      checkout_expires_at: 1.hour.ago,
      checkout_url: "https://checkout.stripe.com/c/pay/old",
      stripe_checkout_session_id: "cs_old",
      previous_signup_status: "confirmed"
    )
    log_in_as(users(:sam))

    with_fake_stripe_checkout do
      post signup_url_for
    end

    assert_redirected_to "https://checkout.stripe.com/c/pay/#{payment.id}"
    payment.reload
    assert_equal "pending", payment.status
    assert_equal "cs_test_#{payment.id}", payment.stripe_checkout_session_id
    assert_in_delta 30.days.from_now.to_i, payment.expires_at.to_i, 5
    assert payment.checkout_expires_at.future?
  end

  test "admin-created participant shared link signs in and opens waiver completion" do
    campsite = campsites(:yosemite_a)
    participant = User.create!(
      first_name: "Morgan",
      last_name: "Direct",
      email: "morgan-direct-link@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    signup = create_campsite_signup!(campsite: campsite, user: participant, arrival_date: nil, checkout_date: nil)
    token = signup.signed_id(purpose: :complete_participant_details)

    get trip_url(trips(:yosemite), complete_signup: token)

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true']" do
      assert_select "h2", "You've been added to the Yosemite Valley Spring trip."
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select "input[type='date'][name='campsite_signup[arrival_date]'][required]"
        assert_select "input[type='date'][name='campsite_signup[checkout_date]'][required]"
      end
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Your trip details have been submitted.", flash[:notice]
    assert participant.reload.default_password?
    assert signup.reload.waiver_signed?
    assert_equal Date.new(2026, 6, 13), signup.arrival_date
    assert_equal Date.new(2026, 6, 15), signup.checkout_date
  end

  test "guest shared link signs in default password guest and opens waiver completion" do
    SiteSetting.current.update!(first_two_nights_fee: "50", extra_night_fee: "10")
    campsite = campsites(:yosemite_a)
    primary_signup = create_campsite_signup!(campsite: campsite, user: users(:sam), arrival_date: Date.new(2026, 6, 13), checkout_date: Date.new(2026, 6, 15))
    primary_signup.payments.create!(
      source: "manual",
      status: "paid",
      amount_cents: 12000,
      manual_payment_method: "venmo",
      manual_paid_at: Time.current,
      paid_at: Time.current
    )
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "guest-link@example.com",
      phone: "555-0303",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_campsite_signup!(
      campsite: campsite,
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )
    token = guest_signup.signed_id(purpose: :complete_guest_details)

    get trip_url(trips(:yosemite), complete_signup: token)

    assert_response :success
    assert_select "[data-controller='modal'][data-modal-open-value='true'][data-modal-clean-url-on-close-value='true']" do
      assert_select "h2", "Gina Guest you've been added to the Yosemite Valley Spring trip by Sam Lee"
      assert_select "p", text: "Please review and sign the waiver."
      assert_select ".participant-details-campsite-summary", text: /Attending June 13, 2026 to June 15, 2026/
      assert_select ".participant-details-campsite-summary", text: /Available June 12, 2026 to June 15, 2026/, count: 0
      assert_select "p", text: "Please select dates you will be attending", count: 0
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']" do
        assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='complete_participant_details']"
        assert_select ".attendance-fields", count: 0
        assert_select ".fee-fields", count: 0
        assert_select "input[type='date'][name='campsite_signup[arrival_date]']", count: 0
        assert_select "input[type='date'][name='campsite_signup[checkout_date]']", count: 0
        assert_select "button", text: "Complete"
        assert_select "button", text: "Pay Now and Complete", count: 0
      end
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "complete_participant_details"
    params[:campsite_signup][:arrival_date] = "2026-06-14"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignupPayment.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "Your waiver has been submitted.", flash[:notice]
    guest_signup.reload
    assert_equal Date.new(2026, 6, 13), guest_signup.arrival_date
    assert_equal Date.new(2026, 6, 15), guest_signup.checkout_date
    assert guest_signup.waiver_signed?
  end

  test "trip detail disables other campsite signup buttons after signup" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}", text: /You are confirmed for this campsite/
    assert_select "#campsite-#{campsites(:yosemite_b).id}" do
      assert_select ".muted", text: /already signed up for another campsite/
    end
  end

  test "trip detail shows waitlist signup button when campsite has no spaces available" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-button")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select "button", text: "Join waitlist"
      assert_select ".danger-stat", text: /0/
      assert_select ".campsite-lock-notice", count: 0
      assert_select ".signup-modal h2", text: "Join trip waitlist"
      assert_select ".waitlist-form .minor-fields[hidden]", text: /Minor information/
      assert_select ".waitlist-form .minor-fields[data-required-dataset-key='requiredForMinor']"
      assert_select ".waitlist-form .minor-fields input[data-required-for-minor='true']", count: 8
      assert_select ".waitlist-form .guest-fields[hidden]", text: /Additional Adults/
      assert_select ".waitlist-form .guest-fields[data-required-dataset-key='requiredForGuest']"
      assert_select ".waitlist-form .guest-fields input[data-required-for-guest='true']", count: 6
    end
    assert_select "#campsite-#{campsites(:yosemite_b).id}" do
      assert_select "button", text: "Sign up for this campsite"
    end
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Join waitlist/
    assert_select "form[action='#{signup_path_for}'][method='post']", text: /Pay Now and Sign Up/, count: 0
  end

  test "logged in user can join waitlist without dates or waiver" do
    fill_campsite_capacity(campsites(:yosemite_a), "waitlist-signup")
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 1 do
      post signup_url_for, params: waitlist_signup_params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waiver_signed?
  end

  test "waitlisted user can sign up for a different open campsite" do
    full_campsite = campsites(:yosemite_a)
    open_campsite = campsites(:yosemite_b)
    fill_campsite_capacity(full_campsite, "waitlisted-open-campsite")
    log_in_as(users(:sam))

    post signup_url_for(full_campsite), params: waitlist_signup_params
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{full_campsite.id}" do
      assert_select "button[disabled]", text: "On waitlist"
    end
    assert_select "#campsite-#{open_campsite.id}" do
      assert_select "button", text: "Signup for campsite"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move you from the waitlist to confirmed"
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='waitlist_direct_signup']"
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "waitlist_direct_signup"
    params[:campsite_signup][:arrival_date] = open_campsite.arrival_date.to_s
    params[:campsite_signup][:checkout_date] = open_campsite.checkout_date.to_s

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(open_campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "You are confirmed for this campsite.", flash[:notice]
    signup.reload
    assert signup.confirmed?
    assert_equal open_campsite, signup.campsite
    assert_equal open_campsite.arrival_date, signup.arrival_date
    assert_equal open_campsite.checkout_date, signup.checkout_date
    assert_not signup.waitlist_eligible?
    assert signup.waiver_signed?
    assert_empty trips(:yosemite).waitlisted_signups.where(user: users(:sam))
  end

  test "waitlisted user with linked party sees party confirmation note for open campsite" do
    full_campsite = campsites(:yosemite_a)
    open_campsite = campsites(:yosemite_b)
    fill_campsite_capacity(full_campsite, "waitlisted-party-open-campsite", count: full_campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for(full_campsite), params: waiver_signature_params_with_guests(
      { first_name: "Gina", last_name: "Guest", email: "waitlisted-party-note@example.com", phone: "" }
    )
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.includes_guests?

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{open_campsite.id}" do
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
      assert_select ".signup-modal-title-line", text: /This will remove you from the waitlist/, count: 0
    end
  end

  test "eligible waitlisted party sees confirm spot for open campsite" do
    campsite = campsites(:yosemite_a)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "eligible-open-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", text: "A spot has opened up!"
      assert_select "button", text: "Confirm your spot"
      assert_select "button", text: "Signup for campsite", count: 0
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td:nth-child(5)", text: "Enabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select "button", text: "Signup", count: 0
      assert_select ".waitlist-transition-note", count: 0
    end
  end

  test "minor under configured age limit does not consume capacity" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "under-capacity", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 6, campsite.reload.confirmed_signup_count
    assert_equal 1, campsite.confirmed_uncounted_minor_count
  end

  test "minor at configured age limit consumes capacity" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "teen-capacity", count: campsite.participant_capacity - 2)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Nora", last_name: "Lee", age: 13, relationship: "Niece" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal 6, campsite.reload.confirmed_signup_count
    assert_equal 0, campsite.available_participant_capacity
  end

  test "whole group is waitlisted when capacity cannot fit counting minors" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "group-waitlist", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    post signup_url_for, params: waiver_signature_params_with_minors(
      { first_name: "Mika", last_name: "Lee", age: 13, relationship: "Child" },
      { first_name: "Nora", last_name: "Lee", age: 14, relationship: "Niece" }
    )

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_equal 5, campsite.reload.confirmed_signup_count
  end

  test "participant and guests are waitlisted together when capacity cannot fit party" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "guest-party-waitlist", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    assert_difference "CampsiteSignup.count", 2 do
      post signup_url_for, params: waiver_signature_params_with_guests(
        { first_name: "Gina", last_name: "Guest", email: "waitlist-party-guest@example.com", phone: "" }
      )
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    guest_signup = signup.guest_signups.first
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_not signup.waiver_signed?
    assert guest_signup.waitlisted?
    assert_nil guest_signup.campsite
    assert_equal 5, campsite.reload.confirmed_signup_count

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".trip-waitlist-section tbody tr", count: 1
    assert_select ".trip-waitlist-section tbody tr", text: /Sam L\. \+ Gina G\./
    assert_select ".trip-waitlist-section", text: /Gina Guest/, count: 0
  end

  test "participant can join waitlist without waiver when selected party exceeds remaining capacity" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "dynamic-party-waitlist", count: campsite.participant_capacity - 1)
    log_in_as(users(:sam))

    params = {
      campsite_signup: {
        intent: "join_waitlist",
        with_guests: "1",
        guest_attributes: {
          "0" => { first_name: "Gina", last_name: "Guest", email: "dynamic-party-waitlist@example.com", phone: "" }
        }
      }
    }

    assert_difference "CampsiteSignup.count", 2 do
      post signup_url_for(campsite), params: params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    guest_signup = signup.guest_signups.first
    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "You have been added to the waitlist for this trip.", flash[:notice]
    assert signup.waitlisted?
    assert_nil signup.campsite
    assert_nil signup.arrival_date
    assert_nil signup.checkout_date
    assert_not signup.waiver_signed?
    assert guest_signup.waitlisted?
    assert_nil guest_signup.campsite
    assert_equal 5, campsite.reload.confirmed_signup_count
  end

  test "locked campsite with open space keeps direct signup closed" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.zone.local(2026, 5, 1, 10))
    log_in_as(users(:sam))

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: waiver_signature_params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "This campsite is using the waitlist.", flash[:alert]

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".campsite-card-header > div:not(.campsite-signup-action) > .campsite-lock-notice", count: 0
      assert_select ".campsite-signup-action .campsite-lock-notice", text: /Spots filled on 5\/2026\.\s+Waitlisted sign ups only/
      assert_select "button", text: "Join waitlist"
    end
  end

  test "eligible waitlisted participant can confirm an open locked campsite spot" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", text: "A spot has opened up!"
      assert_select "button", text: "Confirm your spot"
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move you from the waitlist to confirmed"
      assert_select "form[action='#{signup_path_for(campsite)}'][method='post']", text: /Confirm/
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td:nth-child(5)", text: "Enabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select "button", text: "Signup", count: 0
      assert_select ".waitlist-transition-note", count: 0
      assert_select "input[type='hidden'][name='campsite_signup[intent]'][value='confirm_waitlist']", count: 0
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.confirmed?
    assert_equal campsite, signup.campsite
    assert_equal campsite.arrival_date, signup.arrival_date
    assert_equal campsite.checkout_date, signup.checkout_date
    assert signup.waiver_signed?
  end

  test "eligible waitlisted participant confirms linked guests into same campsite and dates" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    signup = create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "confirm-linked-guest@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    guest_signup = create_waitlisted_signup!(
      trip: trips(:yosemite),
      user: guest_user,
      guest_of_signup: signup,
      guest_position: 1
    )
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".signup-modal-title-line .waitlist-transition-note", text: "This will move your party from the waitlist to confirmed"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td:nth-child(5)", text: "Enabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select ".waitlist-transition-note", count: 0
    end

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"
    params[:campsite_signup][:arrival_date] = "2026-06-13"
    params[:campsite_signup][:checkout_date] = "2026-06-15"

    assert_no_difference "CampsiteSignup.count" do
      post signup_url_for(campsite), params: params
    end

    assert_redirected_to trip_url(trips(:yosemite))
    signup.reload
    guest_signup.reload
    assert signup.confirmed?
    assert_not signup.waitlist_eligible?
    assert guest_signup.confirmed?
    assert_equal campsite, guest_signup.campsite
    assert_equal Date.new(2026, 6, 13), guest_signup.arrival_date
    assert_equal Date.new(2026, 6, 15), guest_signup.checkout_date
    assert_not guest_signup.waiver_signed?
  end

  test "ineligible waitlisted participant does not see confirm action for open locked campsite spot" do
    campsite = campsites(:yosemite_a)
    campsite.update!(signups_locked_at: Time.current)
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsite.id}" do
      assert_select ".spot-open-message", count: 0
      assert_select "button", text: "Confirm your spot", count: 0
      assert_select "button[disabled]", text: "On waitlist"
    end
    assert_select ".trip-waitlist-section tbody tr" do
      assert_select "td:nth-child(5)", text: "Disabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select "button", text: "Signup", count: 0
    end
  end

  test "waitlist confirmation fails if capacity disappears" do
    campsite = campsites(:yosemite_a)
    fill_campsite_capacity(campsite, "confirm-race")
    campsite.lock_signups!
    create_waitlisted_signup!(trip: trips(:yosemite), user: users(:sam), waitlist_eligible_at: Time.current)
    log_in_as(users(:sam))

    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:intent] = "confirm_waitlist"

    post signup_url_for(campsite), params: params

    assert_redirected_to trip_url(trips(:yosemite))
    assert_equal "That campsite spot is no longer available.", flash[:alert]
    signup = CampsiteSignup.find_by!(trip: trips(:yosemite), user: users(:sam))
    assert signup.waitlisted?
    assert_nil signup.campsite
  end

  test "trip detail shows almost full warning at seventy five percent capacity" do
    trip = trips(:yosemite)
    7.times do |index|
      campsite = index < 6 ? campsites(:yosemite_a) : campsites(:yosemite_b)
      create_campsite_signup!(campsite:, user: User.create!(
        first_name: "Almost",
        last_name: "FullView#{index}",
        email: "almost-full-view#{index}@example.com",
        password: "password"
      ))
    end

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-title-line .warning-status", count: 0
    assert_select ".stats .warning-stat", count: 0

    create_campsite_signup!(campsite: campsites(:yosemite_b), user: User.create!(
      first_name: "Almost",
      last_name: "FullViewThreshold",
      email: "almost-full-view-threshold@example.com",
      password: "password"
    ))

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-title-line .warning-status", text: "Almost Full"
    assert_select ".trip-title-line .danger-status", count: 0
    assert_select ".stats .warning-stat", text: /2/
    assert_select ".stats .warning-stat", text: /Open Spaces/
  end

  test "public confirmed participants table abbreviates names and hides contact details" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), arrival_date: Date.new(2026, 6, 13))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".participant-list", count: 0
      assert_select "table.confirmed-participants-table"
      assert_equal [ "Participant", "Dates", "Waiver", "Member", "Minors" ], css_select(".confirmed-participants-table th").map { |header| header.at_css(".tooltip-heading > span:first-child")&.text&.strip || header.text.strip }
      participant_groups = css_select(".campsite-participant-groups").first.to_html
      assert_operator participant_groups.index("Confirmed participants"), :<, participant_groups.index("Parking Spots: 2")
      assert_select ".public-campsite-parking-section" do
        assert_select "h4", "Parking Spots: 2"
        assert_select ".info-tooltip-icon", text: "i"
        assert_select ".info-tooltip-box", text: /Parking is assigned prior to the trip in this order:/
        assert_select ".info-tooltip-box", text: /1\. The person who reserved the campsite/
        assert_select ".info-tooltip-box", text: /Please don't park in an assigned spot\./
        assert_select ".campsite-parking-table tbody tr", count: 2
        assert_select "td", text: "Spot 1"
        assert_select "td", text: "TBD"
      end
      assert_select ".confirmed-participants-table tbody tr", count: 1
      assert_select ".confirmed-participants-table tbody tr" do
        assert_select ".public-party-participant-name", text: "Sam L."
        assert_select "td", text: "No"
        assert_select "td[data-label='Dates'] > span:first-child", text: "Jun 13-Jun 15"
        assert_select "td[data-label='Participant'] .public-participant-mobile-status-line", text: /Non-Member/
        assert_select "td[data-label='Participant'] .public-participant-mobile-status-line", text: /Waiver Missing/
        assert_select "td", text: "Missing"
        assert_select "td", text: "None", count: 0
        assert_select "td .parking-status-with-tooltip", count: 0
      end
      assert_select ".parking-status-groups", count: 0
      assert_select ".confirmed-participants-table a", text: "Missing", count: 0
      assert_select ".confirmed-participants-table", text: /Sam Lee/, count: 0
      assert_select ".confirmed-participants-table", text: /555-0101/, count: 0
      assert_select ".confirmed-participants-table", text: /sam@example.com/, count: 0
    end
  end

  test "public parking section shows campsite spot assignments" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:alex))
    open_spot_user = User.create!(first_name: "Opal", last_name: "Open", email: "public-open-parking@example.com", password: "password")
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: open_spot_user)
    guest_user = User.create!(first_name: "Gina", last_name: "Guest", email: "public-parking-guest@example.com", password: "password")
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1
    )
    campsite_parking_spots(:yosemite_a_1).update!(status: "assigned", assigned_campsite_signup: primary_signup)
    campsite_parking_spots(:yosemite_a_2).update!(status: "first_come_first_serve")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .public-campsite-parking-section" do
      assert_select "td", text: "Spot 1"
      assert_select "td", text: "Alex R."
      assert_select "td", text: "Spot 2"
      assert_select "td", text: "First Come First Serve"
      assert_select ".info-tooltip-icon", text: "i"
      assert_select ".info-tooltip-box", text: /After that parking spots are First Come First Serve\./
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Reserved Spot/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Open Spot/, count: 0
  end

  test "public confirmed participants table links missing waiver only for the signed in participant" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    expected_path = trip_path(
      trips(:yosemite),
      complete_signup: signup.signed_id(purpose: :complete_participant_details),
      anchor: "campsite-#{campsites(:yosemite_a).id}"
    )
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table a.missing-value.missing-link[href='#{expected_path}']", text: "Missing"
  end

  test "public confirmed participants table does not link missing waivers for other participants" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    log_in_as(users(:alex))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Missing/
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table a", text: "Missing", count: 0
  end

  test "public confirmed participants table opens guest waiver link modal for primary participant" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "public-guest-missing-link@example.com",
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
    guest_link = trip_path(trips(:yosemite), complete_signup: guest_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    guest_url = trip_url(trips(:yosemite), complete_signup: guest_signup.signed_id(purpose: :complete_guest_details), anchor: "campsite-#{campsites(:yosemite_a).id}")
    log_in_as(users(:sam))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table" do
      assert_select "button.missing-value.missing-link[data-action='modal#open']", text: "Missing"
      assert_select "dialog.guest-waiver-link-modal" do
        assert_select "h2", "Guest waiver link"
        assert_select "p", text: /Send this to Gina G\. so they can sign the waiver\./
        assert_select "a.missing-details-link[href='#{guest_link}']", text: "Waiver Link"
        assert_select "button.copy-link-button[data-action='copy-link#copy']", text: "Copy Link"
        assert_select "[data-controller='copy-link'][data-copy-link-url-value='#{guest_url}']"
        assert_select "form[action=?][method='post'][data-controller='email-link'][data-action='submit->email-link#send'] button", trip_guest_waiver_email_path(trips(:yosemite), guest_signup), text: "Email link to guest"
      end
    end
  end

  test "public confirmed participants table does not open guest waiver modal for other participants" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "public-other-guest-missing-link@example.com",
      password: User::DEFAULT_GUEST_PASSWORD,
      default_password: true
    )
    create_campsite_signup!(
      campsite: campsites(:yosemite_a),
      user: guest_user,
      guest_of_signup: primary_signup,
      guest_position: 1,
      arrival_date: primary_signup.arrival_date,
      checkout_date: primary_signup.checkout_date
    )
    log_in_as(users(:alex))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Missing/
    assert_select "dialog.guest-waiver-link-modal", count: 0
    assert_select "button.missing-value.missing-link[data-action='modal#open']", text: "Missing", count: 0
  end

  test "public confirmed participants table shows signed waiver status" do
    attach_test_waiver_to(create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam)))

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table tbody tr" do
      assert_select "td", text: "Signed"
      assert_select "td", text: "Missing", count: 0
    end
  end

  test "public confirmed participants table summarizes minors without names" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 10)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 9, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table tbody tr" do
      assert_select ".public-party-participant-name", text: "Sam L."
      assert_select "td[data-label='Dates'] > span:first-child", text: "Jun 12-Jun 15"
      assert_select "td", text: "1 under 10yrs"
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Mika/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /1 minor/, count: 0
  end

  test "public confirmed participants table separates minor age categories" do
    SiteSetting.current.update!(uncounted_minor_age_limit: 10)
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 9, relationship: "Child")
    signup.campsite_signup_minors.create!(first_name: "Teen", last_name: "Lee", age: 12, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table tbody tr" do
      assert_select "td", text: "1 under 10yrs and 1 over 10yrs"
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Mika/, count: 0
    assert_select "#campsite-#{campsites(:yosemite_a).id} .confirmed-participants-table", text: /Teen/, count: 0
  end

  test "public confirmed participants table groups guest rows with primary participant" do
    primary_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:alex))
    guest_user = User.create!(
      first_name: "Gina",
      last_name: "Guest",
      email: "public-confirmed-guest@example.com",
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

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select "#campsite-#{campsites(:yosemite_a).id}" do
      assert_select ".confirmed-participants-table tbody tr", count: 2
      rows = css_select(".confirmed-participants-table tbody tr")
      assert_includes rows.first["class"], "public-party-primary-row"
      assert_includes rows.last["class"], "public-party-guest-row"
      assert_includes rows.last["class"], "public-party-last-row"
      assert_select ".confirmed-participants-table tbody tr:first-child" do
        assert_select ".public-party-participant-name", text: "Alex R."
        assert_select "td", text: "Yes"
        assert_select ".public-added-by", count: 0
      end
      assert_select ".confirmed-participants-table tbody tr:last-child" do
        assert_select "td", text: /Gina G\./
        assert_select "td", text: "No"
        assert_select ".public-added-by", count: 0
      end
      assert_select ".confirmed-participants-table", text: /Alex Rivera/, count: 0
      assert_select ".confirmed-participants-table", text: /Gina Guest/, count: 0
      assert_select ".confirmed-participants-table", text: /public-confirmed-guest@example.com/, count: 0
    end
  end

  test "public stats split out uncounted minors" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")

    get trip_url(trips(:yosemite))

    assert_response :success
    assert_select ".split-signup-stat section:first-child", text: /1/
    assert_select ".split-signup-stat section:first-child", text: /Signed up/
    assert_select ".split-signup-stat section:last-child", text: /1/
    assert_select ".split-signup-stat section:last-child", text: /Under #{SiteSetting.current.uncounted_minor_age_limit}/
    assert_select ".split-signup-stat section:last-child .under-minor-tooltip" do
      assert_select ".info-tooltip-icon", text: "i"
      assert_select ".info-tooltip-box", text: "Children under 10 don't count against Total Capacity"
    end
    assert_select "#campsite-#{campsites(:yosemite_a).id} .campsite-stats .split-signup-stat" do
      assert_select "section:first-child", text: /1/
      assert_select "section:first-child", text: /Signed up/
      assert_select "section:last-child", text: /1/
      assert_select "section:last-child", text: /Under #{SiteSetting.current.uncounted_minor_age_limit}/
      assert_select "section:last-child .under-minor-tooltip" do
        assert_select ".info-tooltip-icon", text: "i"
        assert_select ".info-tooltip-box", text: "Children under 10 don't count against Total Capacity"
      end
    end
  end

  test "public trip detail shows waitlisted users separately" do
    trip = trips(:yosemite)
    waitlisted_user = User.create!(first_name: "Willa", last_name: "Wait", email: "willa@example.com", password: "password")
    willa_joined_at = Time.zone.local(2026, 5, 2, 9, 15)
    alex_joined_at = Time.zone.local(2026, 5, 3, 16, 45)
    campsites(:yosemite_a).lock_signups!
    create_waitlisted_signup!(trip: trip, user: waitlisted_user, created_at: willa_joined_at)
    create_waitlisted_signup!(trip: trip, user: users(:alex), created_at: alex_joined_at, waitlist_eligible_at: Time.current)

    get trip_url(trip)

    assert_response :success
    assert_select ".trip-waitlist-section", text: /Trip waitlist/
    assert_select ".trip-waitlist-note", text: "Waitlist priority goes to club members"
    assert_select ".trip-waitlist-section table.waitlist-table"
    waitlist_headers = css_select(".trip-waitlist-section th").map { |header| header.text.strip }
    assert_equal [ "Priority", "Participant", "Member", "Joined Waitlist", "Self Signup", "Availability", "" ], waitlist_headers
    assert_select ".trip-waitlist-section tbody tr:first-child" do
      assert_select "td", text: "1"
      assert_select "td", text: "Alex R."
      assert_select "td", text: "Member"
      assert_select "td", text: alex_joined_at.strftime("%-m/%-d/%y %-l:%M%P")
      assert_select "td:nth-child(5)", text: "Enabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select "button", text: "Signup", count: 0
    end
    assert_select ".trip-waitlist-section tbody tr:last-child" do
      assert_select "td", text: "2"
      assert_select "td", text: "Willa W."
      assert_select "td", text: "Non-member"
      assert_select "td", text: willa_joined_at.strftime("%-m/%-d/%y %-l:%M%P")
      assert_select "td:nth-child(5)", text: "Disabled"
      assert_select "td:nth-child(6)", text: "Yes"
      assert_select "button", text: "Signup", count: 0
    end
    assert_select ".trip-waitlist-section .participant-list", count: 0
    assert_select ".waitlisted-signups-section", text: /Willa Wait/, count: 0
    assert_select ".waitlisted-signups-section", text: /willa@example.com/, count: 0
  end

  private

  def log_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
    follow_redirect!
  end

  def waiver_signature_params_with_minors(*minor_attributes)
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:with_minors] = "1"
    params[:campsite_signup][:campsite_signup_minors_attributes] = minor_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def waiver_signature_params_with_guests(*guest_attributes)
    params = waiver_signature_params.deep_dup
    params[:campsite_signup][:with_guests] = "1"
    params[:campsite_signup][:guest_attributes] = guest_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def waiver_signature_params_with_minors_and_guests(minor_attributes, guest_attributes)
    params = waiver_signature_params_with_minors(*minor_attributes)
    params[:campsite_signup][:with_guests] = "1"
    params[:campsite_signup][:guest_attributes] = guest_attributes.each_with_index.to_h do |attributes, index|
      [ index.to_s, attributes ]
    end
    params
  end

  def signup_url_for(campsite = campsites(:yosemite_a))
    trip_campsite_campsite_signup_url(campsite.trip, campsite)
  end

  def signup_path_for(campsite = campsites(:yosemite_a))
    trip_campsite_campsite_signup_path(campsite.trip, campsite)
  end

  def waitlist_signup_params
    {
      campsite_signup: {
        intent: "join_waitlist",
        signup_kind: "self"
      }
    }
  end

  def create_class_trip!(attributes = {})
    defaults = {
      trip_type: "class_trip",
      name: "Intro to Anchors",
      location: "Castle Rock, CA",
      start_date: Date.new(2026, 10, 12),
      status: "published",
      participant_capacity: 10,
      partner_company: partner_companies(:vertical_world),
      class_signup_url: "https://example.com/classes/anchors",
      class_original_price: "250",
      weather_url: "https://forecast.weather.gov/castle-rock",
      description: "Learn anchors."
    }

    Trip.create!(defaults.merge(attributes))
  end

  def stripe_checkout_event(type, payment, payment_intent: nil)
    {
      id: "evt_test_#{payment.id}",
      type: type,
      data: {
        object: {
          id: payment.stripe_checkout_session_id,
          object: "checkout.session",
          payment_intent: payment_intent,
          metadata: {
            campsite_signup_payment_id: payment.id.to_s,
            campsite_signup_id: payment.campsite_signup_id.to_s
          }
        }
      }
    }.to_json
  end

  def with_fake_stripe_checkout
    original_creator = Rails.application.config.x.stripe_checkout_session_creator
    Rails.application.config.x.stripe_checkout_session_creator = FakeStripeCheckoutSessionCreator
    yield
  ensure
    Rails.application.config.x.stripe_checkout_session_creator = original_creator
  end

  def with_fake_stripe_refund(stripe_refund)
    original_create = Stripe::Refund.method(:create)
    Stripe::Refund.define_singleton_method(:create) { |_params| stripe_refund }
    yield
  ensure
    Stripe::Refund.define_singleton_method(:create, original_create)
  end

  def fill_campsite_capacity(campsite, prefix, count: campsite.participant_capacity)
    count.times do |index|
      create_campsite_signup!(
        campsite: campsite,
        user: User.create!(
          first_name: "Confirmed",
          last_name: "#{prefix.camelize}#{index}",
          email: "#{prefix}-#{campsite.id}-#{index}@example.com",
          password: "password"
        )
      )
    end
  end
end
