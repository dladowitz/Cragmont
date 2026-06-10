require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "html emails use Cragmont template" do
    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset
    html = mail.html_part.body.decoded

    assert_includes html, "Cragmont"
    assert_includes html, "Climbing Club"
    assert_includes html, "vent-five-emperor-boulder"
    assert_includes html, "font-family: Arial, Helvetica, sans-serif"
    assert_includes html, "margin-left: 20%"
    assert_includes html, "See you at the crag."
  end

  test "text emails include shared header and footer" do
    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset
    text = mail.text_part.body.decoded

    assert_match(/\ACragmont Climbing Club/, text)
    assert_includes text, "Hi #{users(:alex).first_name},"
    assert_includes text, "See you at the crag.\nCragmont Climbing Club"
  end

  test "mailgun delivery method posts rendered email to mailgun api" do
    delivery_method = MailgunDeliveryMethod.new(api_key: "test-key", domain: "mg.example.com")
    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset
    response = Net::HTTPSuccess.new("1.1", "200", "OK")

    original_post_form = Net::HTTP.method(:post_form)
    test_case = self
    Net::HTTP.define_singleton_method(:post_form) do |uri, params|
      test_case.assert_equal "api:test-key", uri.userinfo
      test_case.assert_equal "api.mailgun.net", uri.host
      test_case.assert_equal "/v3/mg.example.com/messages", uri.path
      test_case.assert_equal "Cragmont Climbing <postmaster@cragmontclimbing.com>", params[:from]
      test_case.assert_equal test_case.users(:alex).email, params[:to]
      test_case.assert_equal "Reset your Cragmont password", params[:subject]
      test_case.assert_includes params[:text], "Hi #{test_case.users(:alex).first_name},"
      test_case.assert_includes params[:html], "Cragmont"

      response
    end

    delivery_method.deliver!(mail)
  ensure
    if original_post_form
      Net::HTTP.define_singleton_method(:post_form, original_post_form)
    end
  end

  test "mailgun delivery method sends simple mail body as text" do
    delivery_method = MailgunDeliveryMethod.new(api_key: "test-key", domain: "mg.example.com")
    mail = Mail.new(
      from: "Cragmont Climbing <postmaster@mg.example.com>",
      to: users(:alex).email,
      subject: "Test",
      body: "Simple text"
    )

    original_post_form = Net::HTTP.method(:post_form)
    test_case = self
    Net::HTTP.define_singleton_method(:post_form) do |_uri, params|
      test_case.assert_equal "Simple text", params[:text]
      Net::HTTPSuccess.new("1.1", "200", "OK")
    end

    delivery_method.deliver!(mail)
  ensure
    if original_post_form
      Net::HTTP.define_singleton_method(:post_form, original_post_form)
    end
  end
end
