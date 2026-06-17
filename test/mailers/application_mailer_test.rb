require "test_helper"
require Rails.root.join("config/canonical_app_host")

class ApplicationMailerTest < ActionMailer::TestCase
  test "canonical app host adds www to the public apex domain" do
    assert_equal "www.cragmontclimbing.com", CanonicalAppHost.normalize("cragmontclimbing.com")
    assert_equal "www.cragmontclimbing.com", CanonicalAppHost.normalize(" www.cragmontclimbing.com ")
    assert_equal "staging.cragmontclimbing.com", CanonicalAppHost.normalize("staging.cragmontclimbing.com")
    assert_equal "localhost", CanonicalAppHost.normalize("localhost")
  end

  test "html emails use Cragmont template" do
    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset
    html = mail.html_part.body.decoded

    assert_includes html, "Cragmont"
    assert_includes html, "Climbing Club"
    assert_includes html, "font-family: Arial, Helvetica, sans-serif"
    assert_includes html, "width: 620px"
    assert_includes html, "Cragmont is not a teaching organization. It's a social base camp."
    assert_includes html, "email-liability-note"
    assert_not_includes html, "vent-five-emperor-boulder"
    assert_not_includes html, "Marin Coast, Emperor Boulder"
    assert_not_includes html, "margin-left: 20%"
    assert_not_includes html, "email-footer"
  end

  test "html emails do not add duplicate layout signoff" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    mail = GuestWaiverMailer.with(
      signup: signup,
      added_by: users(:alex),
      waiver_url: "https://example.com/waiver"
    ).needed
    html = mail.html_part.body.decoded

    assert_includes html, "See you at the Crag."
    assert_equal 1, html.scan("See you at the Crag.").size
    assert_not_includes html, "email-footer"
  end

  test "text emails include shared header and footer" do
    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset
    text = mail.text_part.body.decoded

    assert_match(/\ACragmont Climbing Club/, text)
    assert_includes text, "Hi #{users(:alex).first_name},"
    assert_includes text, "Cragmont is not a teaching organization. It's a social base camp."
    assert_includes text, "See you at the crag.\nCragmont Climbing Club"
  end

  test "emails use editable liability warning from settings" do
    SiteSetting.current.update!(liability_warning: "Custom email liability warning.")

    mail = PasswordResetMailer.with(user: users(:alex), token: "reset-token").reset

    assert_includes mail.html_part.body.decoded, "Custom email liability warning."
    assert_includes mail.text_part.body.decoded, "Custom email liability warning."
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
