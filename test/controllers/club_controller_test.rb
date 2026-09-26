require "test_helper"

class ClubControllerTest < ActionDispatch::IntegrationTest
  test "club pages are public and linked from navigation" do
    get about_url
    assert_response :success
    assert_select "h1", "About the Club"
    assert_select "nav.public-nav details[open]", count: 0
    assert_select "nav.public-nav details", count: 2
    assert_select "nav.public-nav details:first-child summary", "Club"
    assert_select "nav.public-nav details:first-child a[href='#{membership_path}']", "Membership"
    assert_select "nav.public-nav details:first-child a[href='#{history_path}']", "History"
    assert_select "nav.public-nav details:first-child a[href='#{new_help_request_path}']", "Get Help"
    assert_select "nav.public-nav details:first-child a[href='#{about_path}']", "About"
    assert_select "nav.public-nav details:nth-child(2) summary", "Trips"
    assert_select "nav.public-nav details:nth-child(2) a[href='#{trips_path}']", "Trips"
    assert_select "nav.public-nav details:nth-child(2) a[href='#{past_trips_path}']", "Past Trips"
    assert_select "nav.public-nav details:nth-child(2) a[href='#{join_the_list_path}']", "Join the List"
    assert_select "nav.public-nav a.nav-auth-login[href='#{new_session_path}']", "Log in"
    assert_select "nav.public-nav a.nav-auth-signup[href='#{new_registration_path}']", "Signup"
    assert_select "nav.club-subnav a[href='#{about_path}'][aria-current='page']", "About"

    get membership_url
    assert_response :success
    assert_select "h1", "Membership"
    assert_select ".club-requirements li", count: 4
    assert_select "nav.club-subnav a[href='#{membership_path}'][aria-current='page']", "Membership"

    get history_url
    assert_response :success
    assert_select "h1", "History"
    assert_select ".club-timeline section", count: 5
    assert_select "article#longer-history h2", "From Cragmont Rock to Yosemite"
    assert_select "article#longer-history section", count: 4
    assert_select ".club-history-sources a[href='https://www.cragmontclimbingclub.org/history']", /Steve Roper's full account/
  end

  test "past trips has a public top-level page" do
    get past_trips_url
    assert_response :success
    assert_select "h1", "Past Trips"
    assert_select ".club-report", count: 22
    assert_select ".club-report h3", "Yosemite Valley - Sept 18th, 2026"
    assert_select ".club-report a[href='https://photos.app.goo.gl/eomxL1uoWFnRjkkJ6']", "View photos"
    assert_select ".club-report-details p", /Vertical Pursuits/
  end

  test "join page embeds the existing Google Form with an accessible fallback" do
    get join_the_list_url
    assert_response :success
    form_url = "https://docs.google.com/forms/d/e/1FAIpQLSdGYS2L_RzoxMxIVP9vM51bdzqy9ivHLbizCE6aS_6FigywXQ/viewform"
    assert_select "iframe.club-form[src='#{form_url}?embedded=true'][title='Join the Cragmont Climbing Club email list']"
    assert_select "a[href='#{form_url}'][target='_blank']", "Open the form in a new tab"
    assert_select "nav.club-subnav a[href='#{join_the_list_path}'][aria-current='page']", "Join the List"
  end
end
