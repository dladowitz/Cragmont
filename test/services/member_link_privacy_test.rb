require "test_helper"

class MemberLinkPrivacyTest < ActiveSupport::TestCase
  test "recognizes member links without hiding ordinary public resources" do
    privacy = MemberLinkPrivacy.new(urls: [ "https://example.com/private-album" ])
    %w[https://chat.whatsapp.com/secret https://wa.me/123 https://photos.app.goo.gl/secret
       https://photos.google.com/share/secret https://sharedalbums.icloud.com/secret
       https://www.icloud.com/sharedalbum/secret https://join.slack.com/t/crag/shared_invite/secret
       https://chat.whatsapp.com/secret🧗 https://CHAT.WHATSAPP.COM./secret
       https://discord.gg/secret https://discord.com/invite/secret https://t.me/+secret
       mailto:member@example.com tel:5550100 https://example.com/private-album].each do |url|
      assert privacy.private_url?(url), url
      assert_not_includes privacy.redact_text("Visit #{url}"), url
    end
    %w[https://forecast.weather.gov/point https://www.mountainproject.com/area/123
       https://maps.google.com/?q=crag https://example.com/classes/anchors
       https://whatsapp.com.example.com/guide].each do |url|
      assert_not privacy.private_url?(url), url
      assert_equal url, privacy.redact_text(url)
    end
  end

  test "redacts URLs in anchors labels titles code and plain text" do
    privacy = MemberLinkPrivacy.new
    secret = "https://chat.whatsapp.com/private-token"
    html = <<~HTML
      <a href="#{secret}" title="#{secret}">#{secret}</a>
      <p title="#{secret}">#{secret} chat.whatsapp.com/bare-token member@example.com</p>
      <code>#{secret}</code><a href="https://custom.example/album-token">Trip photos</a>
      <p>Also https://custom.example/album-token</p>
      <a href="/help">Contact us</a><a href="https://example.com/guide">Guide</a>
    HTML
    redacted = privacy.redact_html(html, login_path: "/session/new?return_to=%2Ftrips")
    %w[private-token bare-token member@example.com album-token].each { |token| assert_not_includes redacted, token }
    assert_includes redacted, 'href="/help"'
    assert_includes redacted, 'href="https://example.com/guide"'
    assert_includes redacted, MemberLinkPrivacy::LOGIN_MESSAGE
  end
end
