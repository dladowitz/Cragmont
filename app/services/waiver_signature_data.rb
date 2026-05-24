require "base64"
require "digest"

class WaiverSignatureData
  DATA_URL_PATTERN = %r{\Adata:image/png;base64,(?<data>[A-Za-z0-9+/=\s]+)\z}
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

  attr_reader :bytes

  def initialize(data_url)
    @data_url = data_url.to_s
  end

  def valid?
    bytes.present?
  end

  def bytes
    @bytes ||= decode
  end

  def digest
    ::Digest::SHA256.hexdigest(bytes)
  end

  private

  def decode
    match = DATA_URL_PATTERN.match(@data_url)
    return unless match

    decoded = Base64.strict_decode64(match[:data].delete("\s\n\r\t"))
    return unless decoded.start_with?(PNG_SIGNATURE)

    decoded
  rescue ArgumentError
    nil
  end
end
