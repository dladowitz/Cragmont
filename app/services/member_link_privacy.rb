# Shared by public prose renderers: invitations and contact details require login.
class MemberLinkPrivacy
  LOGIN_MESSAGE = "Log in to reveal member links".freeze
  URL_PATTERN = %r{(?:https?://|mailto:|tel:|(?:[a-z0-9-]+\.)+[a-z]{2,}/)[^\s<>"']+|[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}}i
  MEMBER_DOMAINS = %w[whatsapp.com wa.me photos.app.goo.gl photos.google.com photos.google sharedalbums.icloud.com discord.gg t.me join.slack.com].freeze

  def initialize(urls: [])
    @urls = urls.map { |url| URI::DEFAULT_PARSER.unescape(url.to_s.strip).tr("\\", "/") }.compact_blank.map { |url| url.sub(%r{\Ahttps?://}i, "") }.compact_blank
  end

  def private_url?(url)
    # Browsers decode escaped hostnames and treat backslashes as URL separators.
    value = URI::DEFAULT_PARSER.unescape(url.to_s).tr("\\", "/")
    return true if @urls.any? { |known| value.sub(%r{\Ahttps?://}i, "").start_with?(known) }
    return true if value.match?(/\A(?:mailto:|tel:|[^\s@]+@[^\s@]+\.[^\s@]+\z)/i)

    value = URI::DEFAULT_PARSER.escape(value)
    uri = URI.parse(value.match?(%r{\A(?:https?:)?//}i) ? value : "https://#{value}")
    host = uri.host.to_s.downcase.delete_suffix(".")
    MEMBER_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") } ||
      (host == "discord.com" && uri.path.start_with?("/invite/")) ||
      (host.end_with?(".slack.com") && uri.path.start_with?("/join/")) ||
      (%w[icloud.com www.icloud.com].include?(host) && uri.path.start_with?("/photos/", "/sharedalbum/"))
  rescue URI::InvalidURIError
    false
  end

  def redact_text(text)
    text.to_s.gsub(URL_PATTERN) { |url| private_url?(url) ? LOGIN_MESSAGE : url }
  end

  def redact_html(html, login_path:)
    fragment = Nokogiri::HTML5.fragment(html.to_s)
    fragment.css("a[href]").each do |link|
      next unless private_url?(link["href"]) || (link["href"].match?(%r{\A(?:https?:)?//}i) && link.text.match?(/\b(?:whatsapp|photos?|album|invite|contact)\b/i))

      @urls << URI::DEFAULT_PARSER.unescape(link["href"]).tr("\\", "/").sub(%r{\Ahttps?://}i, "")
      link.attribute_nodes.each(&:remove)
      link["href"] = login_path
      link.content = LOGIN_MESSAGE
    end
    fragment.traverse do |node|
      if node.text?
        node.content = redact_text(node.content)
      elsif node.element?
        node.attribute_nodes.each do |attribute|
          attribute.value = redact_text(attribute.value)
        end
      end
    end
    fragment.to_html
  end
end
