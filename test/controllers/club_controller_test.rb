require "test_helper"

class ClubControllerTest < ActionDispatch::IntegrationTest
  setup { LegacyTripReportImport.call }
  test "club pages are public and linked from navigation" do
    get about_url
    assert_response :success
    assert_select "h1", "About the Club"
    assert_select "nav.public-nav details[open]", count: 0
    assert_select "nav.public-nav details", count: 3
    assert_select "nav.public-nav details:first-child summary", "Trips"
    assert_select "nav.public-nav details:first-child a[href='#{trips_path}']", "Trips"
    assert_select "nav.public-nav details:first-child a[href='#{past_trips_path}']", "Past Trips"
    assert_select "nav.public-nav details:first-child a[href='#{trip_reports_path}']", "Trip Reports"
    assert_select "nav.public-nav details:first-child a[href='#{join_the_list_path}']", count: 0
    assert_select "nav.public-nav details:nth-child(2) summary", "Resources"
    assert_select "nav.public-nav details:nth-child(2) a" do |links|
      assert_equal [ "Training", "Vendors", "News", "Upcoming Events" ], links.map(&:text)
    end
    assert_select "nav.public-nav details:nth-child(3) summary", "Club"
    assert_select "nav.public-nav details:nth-child(3) a[href='#{membership_path}']", "Membership"
    assert_select "nav.public-nav details:nth-child(3) a[href='#{history_path}']", "History"
    assert_select "nav.public-nav details:nth-child(3) a[href='#{new_help_request_path}']", "Get Help"
    assert_select "nav.public-nav details:nth-child(3) a[href='#{about_path}']", "About"
    assert_select "nav.public-nav details:nth-child(3) a" do |links|
      assert_equal [ "Membership", "History", "About", "Join the List", "Get Help" ], links.map(&:text)
    end
    assert_select "nav.public-nav a.nav-auth-login[href='#{new_session_path}']", "Log in"
    assert_select "nav.public-nav a.nav-auth-signup[href='#{new_registration_path}']", "Signup"
    assert_select "nav.club-subnav", count: 0

    get membership_url
    assert_response :success
    assert_select "h1", "Membership"
    assert_select ".club-requirements li", count: 4
    assert_select "nav.club-subnav", count: 0

    get history_url
    assert_response :success
    assert_select "h1", "History"
    assert_select ".club-copy p", "by Steve Roper (reprinted with permission)"
    assert_select ".club-copy p", /They are the first modern-day climbing heroes of Yosemite/
    assert_select ".club-history-photos img", count: 4
    assert_select ".club-timeline", count: 0
  end

  test "past trips has a public top-level page" do
    get past_trips_url
    assert_response :success
    assert_select "h1", "Past Trips"
    assert_select ".club-report", count: 0
    assert_select "nav.public-nav a[href='#{trip_reports_path}']", count: 1
  end

  test "trip reports have their own public gallery with album links and full reports" do
    get trip_reports_url
    assert_response :success
    assert_select "h1", "Trip Reports"
    assert_select ".club-report", count: 22
    assert_select ".club-report-gallery img[loading='lazy'][width][height]", count: 22
    assert_select ".club-report-gallery img[src^='/assets/trip-reports/']", count: 22
    assert_select ".club-report-gallery-placeholder", count: 0
    thumbnails = Rails.root.glob("app/assets/images/trip-reports/*.jpg")
    assert_equal 22, thumbnails.size
    thumbnails.each do |file|
      assert_equal "\xFF\xD8".b, File.binread(file, 2), "#{file.basename} must be a JPEG, not an error response"
      path = ActionController::Base.helpers.asset_path("trip-reports/#{file.basename}")
      assert_select ".club-report-gallery img[src='#{path}']", count: 1
    end
    assert_select ".club-report h2", "Yosemite Valley - Sept 18th, 2026"
    assert_select ".club-report-gallery a[href='https://photos.app.goo.gl/eomxL1uoWFnRjkkJ6']", count: 1
    assert_select ".club-report a", text: "View photos", count: 0
    assert_select ".club-report-details p", /Vertical Pursuits/
  end

  test "a saved album cover replaces the archive thumbnail on the card and full report" do
    album = "https://photos.app.goo.gl/eomxL1uoWFnRjkkJ6"
    cover = AlbumCover.create!(album_url: album, source_url: "https://lh3.googleusercontent.com/pw/crew=w960-h960")
    cover.image.attach(io: Rails.root.join("app/assets/images/trip-reports/2026-08-14-tuolumne.jpg").open, filename: "album-cover.jpg", content_type: "image/jpeg")

    get trip_reports_url
    assert_response :success
    assert_select ".club-report-gallery img[src^='/assets/trip-reports/']", count: 21
    assert_select ".club-report-gallery a[href='#{album}'] img[src*='/rails/active_storage/blobs/']", count: 1
    assert_select ".club-report-gallery a[href='#{album}'] img[src^='/assets/']", count: 0
    assert_select ".club-report a", text: "View photos", count: 0
    get css_select(".club-report-gallery img[src*='/rails/active_storage/']").first["src"]
    follow_redirect!
    assert_response :success
    assert_equal "image/jpeg", response.media_type

    get trip_report_url(TripReport.find_by!(legacy_key: "2026-09-18-yosemite-valley"))
    assert_select ".club-report-gallery img", count: 1
    assert_select ".club-report-gallery a[href='#{album}'] img[src*='/rails/active_storage/blobs/']", count: 1
  end

  test "an automatic report shows its album cover once one is saved" do
    trip = trips(:yosemite)
    trip.update!(start_date: Date.new(2026, 6, 12), end_date: Date.new(2026, 6, 15), auto_trip_report: true,
      photo_album_url: "https://photos.app.goo.gl/automatic")
    travel_to Time.utc(2026, 10, 6) do
      get trip_trip_report_url(trip)
      assert_select ".club-report-gallery-placeholder", count: 1
      assert_select ".club-report a.report-album-card[href='https://photos.app.goo.gl/automatic']", "View photos"

      cover = AlbumCover.create!(album_url: trip.photo_album_url, source_url: "https://lh3.googleusercontent.com/pw/auto=w960-h960")
      cover.image.attach(io: Rails.root.join("app/assets/images/trip-reports/2026-08-14-tuolumne.jpg").open, filename: "album-cover.jpg", content_type: "image/jpeg")
      get trip_trip_report_url(trip)
      assert_select ".club-report-gallery-placeholder", count: 0
      assert_select ".club-report-gallery a[href='https://photos.app.goo.gl/automatic'] img[src*='/rails/active_storage/blobs/']", count: 1
      assert_select ".club-report a", text: "View photos", count: 0
    end
  end

  test "page switching stays in the top navigation rather than page content" do
    resource_paths = Resource::CATEGORIES.keys.map { |category| resource_category_path(category) }
    destinations = [ trips_path, past_trips_path, past_trips_trips_path, trip_reports_path,
      about_path, membership_path, history_path, join_the_list_path ] + resource_paths
    article = Resource.create!(user: users(:sam), category: "news", kind: "article", title: "Club news", body: "Fresh chalk.")
    (destinations.uniq + [ trip_report_path(TripReport.first!), resource_article_path("news", article) ]).each do |path|
      get path
      assert_response :success
      assert_select "nav.public-nav a[href='#{trips_path}']", count: 1
      assert_select "nav.public-nav a[href='#{membership_path}']", count: 1
      destinations.each do |destination|
        next if path == membership_path && destination == join_the_list_path
        assert_select "main a[href='#{destination}']", count: 0
      end
      assert_select "main nav.club-subnav", count: 0
    end
  end

  test "public pages do not show the obsolete site beta banner" do
    [ root_url, trips_url, past_trips_url, trip_reports_url, about_url, membership_url,
      history_url, join_the_list_url, new_session_url, new_registration_url,
      new_help_request_url, trip_url(trips(:yosemite)) ].each do |url|
      get url
      assert_response :success
      assert_no_match(/still getting dialed in/i, response.body, url)
    end
  end

  test "join page embeds the existing Google Form with an accessible fallback" do
    get join_the_list_url
    assert_response :success
    form_url = "https://docs.google.com/forms/d/e/1FAIpQLSdGYS2L_RzoxMxIVP9vM51bdzqy9ivHLbizCE6aS_6FigywXQ/viewform"
    assert_select "iframe.club-form[src='#{form_url}?embedded=true'][title='Join the Cragmont Climbing Club email list']"
    assert_select "a[href='#{form_url}'][target='_blank']", "Open the form in a new tab"
    assert_select "nav.club-subnav", count: 0
  end
end
