# Shared by public prose renderers: invitations and contact details require login.
class MemberLinkPrivacy
  LOGIN_MESSAGE = "Log in to reveal member links".freeze
  URL_PATTERN = %r{(?:https?://|mailto:|tel:|(?:[a-z0-9-]+\.)+[a-z]{2,}/)[^\s<>"']+|[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}}i
  CONTACT_PATTERN = /\A(?:mailto:|tel:|[^\s@]+@[^\s@]+\.[^\s@]+\z)/i
  MEMBER_DOMAINS = %w[whatsapp.com wa.me photos.app.goo.gl photos.google.com photos.google sharedalbums.icloud.com discord.gg t.me join.slack.com].freeze

  def initialize(urls: [])
    @urls = urls.map { |url| normalize_url(url) }.compact_blank
  end

  def private_url?(url)
    value = normalize_url(url)
    return true if @urls.any? { |known| value.start_with?(known) }
    return true if value.match?(CONTACT_PATTERN)

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

      @urls << normalize_url(link["href"])
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

  private

  def normalize_url(url)
    # Match browser handling of escaped hosts, whitespace, and URL separators.
    value = URI::DEFAULT_PARSER.unescape(url.to_s).strip.delete("\t\r\n").tr("\\", "/")
    return value if value.blank? || value.match?(CONTACT_PATTERN)

    uri = URI.parse(URI::DEFAULT_PARSER.escape(value.match?(%r{\A(?:https?:)?//}i) ? value : "https://#{value}"))
    return value if uri.host.blank?

    uri.host = uri.host.downcase.sub(/(?<=.)\.\z/, "")
    URI::DEFAULT_PARSER.unescape(uri.to_s).sub(%r{\A(?:https?:)?//}i, "")
  rescue URI::InvalidURIError
    value
  end
end
