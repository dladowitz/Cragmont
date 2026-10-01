require "test_helper"

class RecurringGymMeetupsTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "preview shows exact dates and preserves fields without saving" do
    assert_no_difference "Trip.count" do
      post admin_trips_url, params: meetup_params.merge(preview_meetups: "1")
    end

    assert_response :success
    assert_select "form#admin-trip-form[data-turbo=false]"
    assert_select "[role=status] li", text: "Thursday, January 1, 2026"
    assert_select "[role=status] li", text: "Thursday, January 15, 2026"
    assert_select "input[name='trip[name]'][value='Recurring gym crew']"
    assert_select "select[name='gym_meetup_schedule[frequency]'] option[selected][value='first_third']"
    assert_select "input[name='gym_meetup_schedule[ends_on]'][value='2026-01-15']"
    assert_select "label[for=trip_campsite_coordinator_id] > span:not([hidden]) .required-marker", text: "*"
  end

  test "preview warns that uploaded images must be selected again without persisting them" do
    Tempfile.create([ "gym-preview", ".png" ]) do |file|
      file.binmode
      file.write(Base64.decode64(SIGNATURE_DATA_URL.split(",").last))
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "image/png")
      attributes = meetup_params
      attributes[:trip][:day_trip_image] = upload

      assert_no_difference [ "Trip.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
        post admin_trips_url, params: attributes.merge(preview_meetups: "1")
      end

      assert_response :success
      assert_select ".admin-trip-location-image-field [role=alert]", text: /Please choose your location image again before saving/
      assert_select ".admin-trip-location-image-field", text: /Current file:/, count: 0
      assert_select "[role=status] li", count: 2
    end
  end

  test "one off gym form does not show a required coordinator marker" do
    get new_admin_trip_url(trip_type: "gym_outing")

    assert_response :success
    assert_select "label[for=trip_campsite_coordinator_id]", text: /Event Coordinator/
    assert_select "label[for=trip_campsite_coordinator_id] > span:not([hidden]) .required-marker", count: 0
    assert_select "label[for=trip_campsite_coordinator_id] > span[hidden] .required-marker", text: "*"
  end

  test "create publishes separate dates with independent edits participants and private calendar output" do
    assert_difference "Trip.count", 2 do
      post admin_trips_url, params: meetup_params
    end
    outings = Trip.where(name: "Recurring gym crew").order(:start_date).to_a
    first, second = outings
    assert_redirected_to admin_trip_url(first)
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 1, 15) ], outings.map(&:start_date)
    assert outings.all?(&:published?)
    assert_equal [ users(:alex).id ], outings.map(&:campsite_coordinator_id).uniq

    DayTripSignup.create!(trip: first, user: users(:sam), climbing_abilities: [ "none" ])
    patch admin_trip_url(second), params: { trip: { location: "Another gym", campsite_coordinator_id: users(:sam).id } }
    assert_redirected_to admin_trip_url(second)
    assert_equal "Movement Sunnyvale", first.reload.location
    assert_equal users(:alex), first.campsite_coordinator
    assert_equal "Another gym", second.reload.location
    assert_equal users(:sam), second.campsite_coordinator
    assert_empty second.day_trip_signups

    delete session_url
    get calendar_trips_url(format: :ics)
    assert_response :success
    outings.each { |trip| assert_includes response.body, "UID:trip-#{trip.id}@cragmontclimbing.com" }
    refute_includes response.body, "private-meetup-invite"
    refute_includes response.body, "private-meetup-album"
    refute_includes response.body, users(:alex).email
    assert_includes response.body, "LOCATION:Another gym"
  end

  test "ordinary trip creation works when schedule parameters are omitted" do
    assert_difference "Trip.count", 1 do
      post admin_trips_url, params: { trip: meetup_params[:trip] }
    end
    assert_response :redirect
  end

  test "invalid schedule and trip fields render errors without saving any dates" do
    [
      { gym_meetup_schedule: { frequency: "weekly", ends_on: "2026-01-15" } },
      { gym_meetup_schedule: { frequency: "first_third", ends_on: "not-a-date" } },
      { trip: meetup_params[:trip].merge(campsite_coordinator_id: "") },
      { trip: meetup_params[:trip].merge(participant_capacity: "0") }
    ].each do |invalid|
      assert_no_difference "Trip.count" do
        post admin_trips_url, params: meetup_params.merge(invalid)
      end
      assert_response :unprocessable_entity
    end
  end

  test "malformed schedule objects return a client error rather than a server error" do
    [ "monthly", [ "monthly" ] ].each do |malformed|
      assert_no_difference "Trip.count" do
        post admin_trips_url, params: meetup_params.merge(gym_meetup_schedule: malformed)
      end
      assert_response :bad_request
    end
  end

  test "anonymous and ordinary members cannot preview or create meetups" do
    delete session_url
    [ false, true ].each do |signed_in|
      log_in_as(users(:sam)) if signed_in
      [ nil, "1" ].each do |preview|
        assert_no_difference "Trip.count" do
          post admin_trips_url, params: meetup_params.merge(preview_meetups: preview)
        end
        assert_response :redirect
        assert_redirected_to(signed_in ? root_url : new_session_url)
      end
    end
  end

  test "editing an outing cannot create further dates" do
    post admin_trips_url, params: meetup_params
    trip = Trip.find_by!(name: "Recurring gym crew")

    get edit_admin_trip_url(trip)
    assert_select "select[name='gym_meetup_schedule[frequency]']", count: 0
    assert_no_difference "Trip.count" do
      patch admin_trip_url(trip), params: meetup_params.merge(gym_meetup_schedule: { frequency: "first_third", ends_on: "2026-12-31" })
    end
    assert_redirected_to admin_trip_url(trip)
  end

  private

  def meetup_params
    {
      trip: { name: "Recurring gym crew", trip_type: "gym_outing", location: "Movement Sunnyvale", start_date: "2026-01-01",
        meeting_time: "13:00", end_time: "15:00", participant_capacity: 10, status: "published", campsite_coordinator_id: users(:alex).id,
        whatsapp_group: "https://chat.whatsapp.com/private-meetup-invite", photo_album_url: "https://example.com/private-meetup-album",
        description: "Join https://chat.whatsapp.com/private-meetup-invite and https://example.com/private-meetup-album" },
      gym_meetup_schedule: { frequency: "first_third", ends_on: "2026-01-15" }
    }
  end
end
