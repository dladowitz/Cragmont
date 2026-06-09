require "test_helper"

class Admin::HelpRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @help_request = HelpRequest.create!(
      user: users(:sam),
      reason: "club_question",
      subject: "Club trip question",
      name: "Sam Lee",
      email: "sam@example.com",
      message: "How do club trips work?"
    )
    log_in_as(users(:alex))
  end

  test "admin can view help requests" do
    get admin_help_requests_url

    assert_response :success
    assert_select "h2", "Help requests"
    assert_equal [ "View", "Subject", "Reason", "From", "Status", "Received" ], css_select("thead th").map { |header| header.text.strip }
    assert_select "td", text: /Club trip question/
    assert_select "td", text: /Question about club/
    assert_select "a[href='#{admin_help_request_path(@help_request)}']", "View"
    assert_select "form.help-request-filter-form[action='#{admin_help_requests_path}'][method='get']"
    assert_select "input#status_open[checked]"
    assert_select "input#status_replied[checked]"
    assert_select "input#status_resolved[checked]"
    assert_select "input[type='submit'][value='Apply']"
  end

  test "admin can filter help requests by status" do
    HelpRequest.create!(
      user: users(:sam),
      reason: "site_issue",
      subject: "Already replied request",
      name: "Sam Lee",
      email: "sam@example.com",
      message: "This one has a reply.",
      status: "replied"
    )
    HelpRequest.create!(
      user: users(:alex),
      reason: "other",
      subject: "Resolved request",
      name: "Alex Rivera",
      email: "alex@example.com",
      message: "This one is resolved.",
      status: "resolved"
    )

    get admin_help_requests_url, params: { status: [ "replied" ] }

    assert_response :success
    assert_select "input#status_open[checked]", count: 0
    assert_select "input#status_replied[checked]"
    assert_select "input#status_resolved[checked]", count: 0
    assert_select "td", text: /Already replied request/
    assert_select "td", text: /Club trip question/, count: 0
    assert_select "td", text: /Resolved request/, count: 0
  end

  test "admin help requests are paginated at twenty per page" do
    25.times do |index|
      HelpRequest.create!(
        user: users(:sam),
        reason: "club_question",
        subject: "Paged request #{index + 1}",
        name: "Sam Lee",
        email: "sam@example.com",
        message: "How does page #{index + 1} work?"
      )
    end

    get admin_help_requests_url

    assert_response :success
    assert_select "tbody tr", 20
    assert_select ".pagination-summary", "Page 1 of 2"
    next_link = css_select(".pagination a").find { |link| link.text.strip == "Next" }
    assert next_link
    assert_includes next_link["href"], "page=2"
    assert_includes next_link["href"], "status%5B%5D=open"
    assert_includes next_link["href"], "status%5B%5D=replied"
    assert_includes next_link["href"], "status%5B%5D=resolved"

    get admin_help_requests_url, params: { page: 2 }

    assert_response :success
    assert_select "tbody tr", 6
    assert_select ".pagination-summary", "Page 2 of 2"
    assert_select "a", text: "Previous"
  end

  test "admin can view resolve action on unresolved request" do
    get admin_help_request_url(@help_request)

    assert_response :success
    assert_select "form[action='#{resolve_admin_help_request_path(@help_request)}']"
    assert_select "button", text: "Mark resolved"
    assert_select ".panel-header .muted", text: /Received/, count: 0
    assert_select ".help-request-title-line h2", text: "Club trip question"
    assert_select ".help-request-title-line .status-pill.open-status", text: "Open"
    assert_select ".help-request-meta-row dt", text: "Reason"
    assert_select ".help-request-meta-row dd", text: "Question about club"
    assert_select ".help-request-meta-row dt", text: "Status", count: 0
    assert_select ".help-reply-heading", text: "Original message"
    assert_select ".help-reply", text: /How do club trips work/
    assert_select ".help-message", count: 0
  end

  test "admin can reply to help request" do
    assert_difference "HelpRequestReply.count", 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post reply_admin_help_request_url(@help_request), params: {
          help_request_reply: {
            message: "On belay! We can help with that.",
            files: [ fixture_file_upload("help-note.txt", "text/plain") ]
          }
        }
      end
    end

    assert_redirected_to admin_help_request_url(@help_request)
    assert_equal "replied", @help_request.reload.status
    assert HelpRequestReply.last.files.attached?

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "sam@example.com" ], mail.to
    assert_equal "Cragmont help request reply: Club trip question", mail.subject
    assert_match "On belay!", mail.text_part.body.decoded
    assert_match "Reply to this message on the site", mail.text_part.body.decoded
    assert_match help_request_path(@help_request), mail.text_part.body.decoded
    reply_url = mail.text_part.body.decoded.lines.find { |line| line.include?(help_request_path(@help_request)) }.strip
    assert_match "access=", reply_url

    delete session_url
    get URI.parse(reply_url).request_uri

    assert_response :success
    assert_select "h1", "Club trip question"
  end

  test "admin can mark help request resolved" do
    patch resolve_admin_help_request_url(@help_request)

    assert_redirected_to admin_help_request_url(@help_request)
    assert_equal "resolved", @help_request.reload.status

    follow_redirect!
    assert_response :success
    assert_select ".help-request-title-line .status-pill.resolved-status", text: "Resolved"
    assert_select "button", text: "Mark resolved", count: 0
  end
end
