require "test_helper"

class HelpRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "renders help form" do
    get new_help_request_url

    assert_response :success
    assert_select "a[href='#{new_help_request_path}']", "Get Help"
    assert_select "h1", "Need Help?"
    assert_select "select[name='help_request[reason]'][required]"
    assert_select "input[name='help_request[subject]'][required]"
    assert_select "input[name='help_request[first_name]'][required]"
    assert_select "input[name='help_request[last_name]'][required]"
    assert_select "input[name='help_request[email]'][required]"
    assert_select "textarea[name='help_request[message]'][required]"
    assert_select "input[type='file'][name='help_request[images][]'][multiple]"
  end

  test "signed in user contact fields render as display text" do
    log_in_as(users(:alex))

    get new_help_request_url

    assert_response :success
    assert_select ".help-contact-label", text: "Name"
    assert_select ".help-contact-value", text: "Alex Rivera"
    assert_select ".help-contact-label", text: "Email"
    assert_select ".help-contact-value", text: "alex@example.com"
    assert_select "input[name='help_request[name]']", count: 0
    assert_select "input[name='help_request[email]']", count: 0
  end

  test "creates help request and notifies subscribers" do
    HelpNotificationSubscriber.create!(email: "admin@example.com")

    assert_difference "HelpRequest.count", 1 do
      assert_difference "User.count", 1 do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
          post create_help_request_url, params: {
            help_request: {
              reason: "site_issue",
              subject: "Checkout anchor",
              first_name: "Taylor",
              last_name: "Granite",
              email: "taylor@example.com",
              message: "The checkout anchor is off route."
            }
          }
        end
      end
    end

    help_request = HelpRequest.last
    user = User.find_by!(email: "taylor@example.com")
    assert_redirected_to help_request_url(help_request)
    assert_equal "Taylor Granite", help_request.name
    assert_equal user, help_request.user
    assert user.default_password?

    follow_redirect!
    assert_response :success
    assert_select "h1", "Checkout anchor"

    admin_mail = ActionMailer::Base.deliveries.find { |mail| mail.to == [ "admin@example.com" ] }
    assert_equal "Cragmont help request: Report site issue", admin_mail.subject

    confirmation = ActionMailer::Base.deliveries.find { |mail| mail.to == [ "taylor@example.com" ] }
    assert_equal "On belay! We got your help request", confirmation.subject
    assert_match "View this help request on the site", confirmation.text_part.body.decoded
    request_url = confirmation.text_part.body.decoded.lines.find { |line| line.include?(help_request_path(help_request)) }.strip
    assert_match "access=", request_url

    delete session_url
    get URI.parse(request_url).request_uri

    assert_response :success
    assert_select "h1", "Checkout anchor"
  end

  test "guest request with existing account links but does not log in from public form" do
    assert_no_difference "User.count" do
      assert_difference "HelpRequest.count", 1 do
        post create_help_request_url, params: {
          help_request: {
            reason: "club_question",
            subject: "Club email question",
            first_name: "Sam",
            last_name: "Lee",
            email: "sam@example.com",
            message: "Can you help me find the club info?"
          }
        }
      end
    end

    help_request = HelpRequest.last
    assert_equal users(:sam), help_request.user
    assert_redirected_to new_help_request_url
  end

  test "signed in user is linked even when disabled contact fields do not submit" do
    log_in_as(users(:alex))

    assert_difference "HelpRequest.count", 1 do
      post create_help_request_url, params: {
        help_request: {
          reason: "trip_help",
          subject: "Campsite help",
          message: "I need help with my campsite."
        }
      }
    end

    help_request = HelpRequest.last
    assert_redirected_to help_request_url(help_request)
    assert_equal users(:alex), help_request.user
    assert_equal "Alex Rivera", help_request.name
    assert_equal "alex@example.com", help_request.email
  end

  test "signed in user without email can enter contact email" do
    user = User.create!(first_name: "No", last_name: "Email", email: "temporary@example.com", password: "password")
    log_in_as(user)
    user.update!(email: nil)

    get new_help_request_url

    assert_response :success
    assert_select ".help-contact-value", text: "No Email"
    assert_select "input[name='help_request[name]']", count: 0
    assert_select "input[name='help_request[email]'][disabled]", count: 0
    assert_select "input[name='help_request[email]'][required]"

    assert_difference "HelpRequest.count", 1 do
      post create_help_request_url, params: {
        help_request: {
          reason: "other",
          subject: "Reply address",
          email: "no-email-contact@example.com",
          message: "I need a reply address."
        }
      }
    end

    help_request = HelpRequest.last
    assert_equal user, help_request.user
    assert_equal "No Email", help_request.name
    assert_equal "no-email-contact@example.com", help_request.email
  end

  test "signed in user can list their help requests" do
    own_request = HelpRequest.create!(
      user: users(:alex),
      reason: "site_issue",
      subject: "Off route page",
      name: "Alex Rivera",
      email: "alex@example.com",
      message: "My page is off route."
    )
    HelpRequest.create!(
      user: users(:sam),
      reason: "other",
      subject: "Sam request",
      name: "Sam Lee",
      email: "sam@example.com",
      message: "This belongs to Sam."
    )
    own_request.replies.create!(user: users(:sam), message: "We are checking it.")
    log_in_as(users(:alex))

    get help_requests_url

    assert_response :success
    assert_select "h1", "My Help Requests"
    assert_equal [ "View", "Subject", "Status", "Replies", "Sent" ], css_select("thead th").map { |header| header.text.strip }
    assert_select "td", text: /Off route page/
    assert_select "td", text: /Report site issue/, count: 0
    assert_select "td", text: /This belongs to Sam/, count: 0
    assert_select "a[href='#{help_request_path(own_request)}']", "View"
  end

  test "signed in user can view conversation and reply with file" do
    help_request = HelpRequest.create!(
      user: users(:alex),
      reason: "trip_help",
      subject: "Trip dates question",
      name: "Alex Rivera",
      email: "alex@example.com",
      message: "I need help with my trip.",
      status: "replied",
      last_replied_at: Time.current
    )
    help_request.images.attach(io: StringIO.new("image"), filename: "screen.png", content_type: "image/png")
    assign_role(users(:sam), :trip_admin)
    help_request.replies.create!(user: users(:sam), message: "On belay, we are looking.")
    HelpNotificationSubscriber.create!(email: "admin@example.com")
    log_in_as(users(:alex))

    get help_request_url(help_request)

    assert_response :success
    assert_select "h1", "Trip dates question"
    assert_select ".help-request-title-line .status-pill.replied-status", text: "Replied"
    assert_select ".panel-header .muted", text: /Sent/, count: 0
    assert_select ".help-reply-heading", text: "Original message"
    assert_select ".help-reply", text: /Need help with trip/
    assert_select ".help-reply", text: /I need help with my trip/
    assert_select ".admin-help-reply", text: /On belay/
    assert_select "button.help-attachment-button", "screen.png"
    assert_select "dialog.help-image-modal img[alt='screen.png']"
    assert_select "a[href*='screen.png']", count: 0
    assert_select "input[type='file'][name='help_request_reply[files][]'][multiple]"

    assert_difference "HelpRequestReply.count", 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        post reply_help_request_url(help_request), params: {
          help_request_reply: {
            message: "Here is a file from my side.",
            files: [ fixture_file_upload("help-note.txt", "text/plain") ]
          }
        }
      end
    end

    reply = HelpRequestReply.last
    assert_equal users(:alex), reply.user
    assert reply.files.attached?
    assert_equal "open", help_request.reload.status
    assert_redirected_to help_request_url(help_request)

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "admin@example.com" ], mail.to
    assert_equal "Cragmont help request updated: Need help with trip", mail.subject
  end

  test "signed in user cannot view someone elses help request" do
    help_request = HelpRequest.create!(
      user: users(:sam),
      reason: "other",
      subject: "Private request",
      name: "Sam Lee",
      email: "sam@example.com",
      message: "Private message."
    )
    log_in_as(users(:alex))

    get help_request_url(help_request)

    assert_response :not_found
  end
end
