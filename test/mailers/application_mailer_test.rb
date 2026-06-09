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
end
