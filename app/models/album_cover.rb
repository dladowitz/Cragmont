require "net/http"

# Copies a shared Google Photos album's cover from its link-preview (og:image) tag, the image chat apps show.
# Google doesn't document that tag, so a failed refresh keeps the last saved copy.
class AlbumCover < ApplicationRecord
  class FetchError < StandardError; end

  MAX_BYTES = 10.megabytes

  has_one_attached :image
  validates :album_url, presence: true, uniqueness: true

  def self.refresh(album_url)
    page = fetch(album_url) { |uri| TripReport.google_album?(uri.to_s) }
    source = Nokogiri::HTML(page).at_css("meta[property='og:image']")&.[]("content")
    raise FetchError, "Album page has no cover image" if source.blank?
    # Same uncropped 960px fit as the archive thumbnails the old site copied.
    source = source.sub(/=[\w-]+\z/, "") + "=w960-h960"
    cover = find_or_initialize_by(album_url: album_url)
    return cover if cover.source_url == source && cover.image.attached?

    data = fetch(source) { |uri| uri.scheme == "https" && uri.host.to_s.end_with?(".googleusercontent.com") }
    raise FetchError, "Cover is not a JPEG, PNG, or WebP image" unless
      %w[image/jpeg image/png image/webp].include?(Marcel::MimeType.for(StringIO.new(data)))
    # Re-encoding fully decodes the image and strips its metadata.
    jpeg = ImageProcessing::Vips.source(Vips::Image.new_from_buffer(data, "", fail_on: :warning))
      .resize_to_limit(960, 960).convert("jpg").saver(strip: true).call
    cover.source_url = source
    cover.image.attach(io: jpeg, filename: "album-cover.jpg", content_type: "image/jpeg")
    cover.save!
    cover
  rescue StandardError => error
    Rails.logger.warn("Album cover refresh failed for #{album_url}: #{error.class}: #{error.message}")
    nil
  end

  # Checks every hop so a redirect can't point the server at another host.
  def self.fetch(url, &allowed)
    uri = URI(url)
    4.times do
      raise FetchError, "Blocked #{uri.host}" unless allowed.call(uri)
      status, location, body = get(uri)
      return body if status == 200
      raise FetchError, "HTTP #{status}" unless (300..399).cover?(status) && location.present?
      uri = URI.join(uri, location)
    end
    raise FetchError, "Too many redirects"
  end

  def self.get(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request_get(uri.request_uri) do |response|
        body = +""
        if response.code == "200"
          response.read_body { |chunk| raise FetchError, "Response too large" if (body << chunk).bytesize > MAX_BYTES }
        end
        return [ response.code.to_i, response["location"], body ]
      end
    end
  end
end
