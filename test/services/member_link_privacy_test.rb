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
    %w[https://. https://forecast.weather.gov/point https://www.mountainproject.com/area/123
       https://maps.google.com/?q=crag https://example.com/classes/anchors
       https://whatsapp.com.example.com/guide].each do |url|
      assert_not privacy.private_url?(url), url
      assert_equal url, privacy.redact_text(url)
    end
  end

  test "redacts browser normalized hostnames and backslash separators" do
    privacy = MemberLinkPrivacy.new(urls: [ "https://example.com/private%20album" ])
    [ "https://example.com/private%20album", "https://chat.whats%61pp.com/encoded-token", "https://chat.whatsapp.com\\backslash-token" ].each do |url|
      assert privacy.private_url?(url)
      assert_equal MemberLinkPrivacy::LOGIN_MESSAGE, privacy.redact_text(url)
      html = privacy.redact_html(%(<a href="#{url}">Join us</a>), login_path: "/session/new")
      assert_not_includes html, url
      assert_includes html, 'href="/session/new"'
    end
  end

  test "normalizes browser whitespace and custom album host case without changing path case" do
    privacy = MemberLinkPrivacy.new(urls: [ " https://EXAMPLE.com/Private%20Album " ])
    [ "https://chat.what\tsapp.com/tab-token", "\n https://chat.whatsapp.com/space-token \r", "https://example.com/Private%20Album" ].each do |url|
      assert privacy.private_url?(url), url
      html = privacy.redact_html(%(<a href="#{url}">Open here</a>), login_path: "/session/new")
      assert_includes html, 'href="/session/new"'
      assert_not_includes html, url
    end
    assert_not privacy.private_url?("https://example.com/private%20album")
    html = privacy.redact_html('<a href="https://EXAMPLE.com/Private%20Album">Photos</a><p>https://example.com/Private%20Album</p>', login_path: "/session/new")
    assert_not_includes html, "Private%20Album"
  end

  test "redacts URLs in anchors labels titles code and plain text" do
    privacy = MemberLinkPrivacy.new
    secret = "https://chat.whatsapp.com/private-token"
    html = <<~HTML
      <a href="#{secret}" title="#{secret}">#{secret}</a>
      <p title="#{secret}">#{secret} chat.whatsapp.com/bare-token member@example.com</p>
      <code>#{secret}</code><a href="https://custom.example/album%20token">Trip photos</a>
      <p>Also https://custom.example/album%20token</p>
      <a href="/help">Contact us</a><a href="https://example.com/guide">Guide</a>
    HTML
    redacted = privacy.redact_html(html, login_path: "/session/new?return_to=%2Ftrips")
    %w[private-token bare-token member@example.com album%20token].each { |token| assert_not_includes redacted, token }
    assert_includes redacted, 'href="/help"'
    assert_includes redacted, 'href="https://example.com/guide"'
    assert_includes redacted, MemberLinkPrivacy::LOGIN_MESSAGE
  end
end
