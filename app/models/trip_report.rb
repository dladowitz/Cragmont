class TripReport < ApplicationRecord
  FIELDS = %w[title start_date end_date location trip_type body byline album_url photos].freeze
  MAX_PHOTOS = 24

  belongs_to :trip, optional: true
  belongs_to :last_edited_by, class_name: "User", optional: true
  has_many_attached :photos

  validates :trip_id, uniqueness: true, allow_nil: true
  validates :legacy_key, uniqueness: true, allow_nil: true
  validate :valid_draft

  def self.google_album?(url)
    uri = URI.parse(url.to_s)
    uri.scheme == "https" && uri.userinfo.nil? && uri.port == 443 &&
      %w[photos.app.goo.gl photos.google.com photos.google].include?(uri.host&.downcase) &&
      uri.path.present? && uri.path != "/"
  rescue URI::InvalidURIError
    false
  end

  def self.for_trip(trip)
    trip.trip_report || new(trip: trip, draft: trip_payload(trip))
  end

  def self.trip_payload(trip)
    { "title" => trip.name, "start_date" => trip.start_date.to_s, "end_date" => trip.end_date.to_s,
      "location" => trip.location, "trip_type" => trip.trip_type, "album_url" => trip.photo_album_url.to_s,
      "body" => "", "byline" => "", "photos" => [] }
  end

  def self.public_reports
    reports = includes(:trip, photos_attachments: :blob).to_a
    linked_ids = reports.filter_map(&:trip_id)
    Trip.visible_for_public.where(auto_trip_report: true).where.not(id: linked_ids).each do |trip|
      reports << for_trip(trip) if trip.automatic_report_eligible?
    end
    reports.select { |report| report.public_payload.present? }
      .sort_by { |report| report.public_payload.fetch("start_date") }.reverse
  end

  def public_payload
    return if hidden?
    return if trip && (!trip.public_report_trip? || !trip.report_ended?)
    return published if published.present?
    self.class.trip_payload(trip) if trip&.automatic_report_eligible?
  end

  def display_status
    return "Hidden" if hidden?
    live = public_payload
    return "Published · unpublished changes" if live.present? && draft != live
    return "Published" if live.present?
    "Draft"
  end

  def save_draft!(attributes, version:, actor:)
    check_version!(version) if persisted?
    self.lock_version = Integer(version.to_s, 10)
    self.draft = draft.merge(attributes.stringify_keys)
    self.last_edited_by = actor
    save!
  end

  def publish!(version:, actor:)
    with_lock do
      check_version!(version)
      valid?
      errors.add(:base, "Add a story, photos, or a Google Photos album before publishing") if
        draft["body"].blank? && draft["album_url"].blank? && Array(draft["photos"]).empty? && draft["legacy_image"].blank?
      errors.add(:base, "Reports can be published after the trip ends") if trip && !trip.report_ended?
      errors.add(:base, "Draft or deleted trips cannot have public reports") if trip && !trip.public_report_trip?
      raise ActiveRecord::RecordInvalid, self if errors.any?
      update!(published: draft.deep_dup, published_at: Time.current, hidden: false, last_edited_by: actor)
    end
  end

  def hide!(version:, actor:)
    with_lock do
      check_version!(version)
      update!(hidden: true, last_edited_by: actor)
    end
  end

  def check_version!(version)
    raise ActiveRecord::StaleObjectError.new(self, "update") unless Integer(version.to_s, 10) == lock_version
  end

  def add_photos!(uploads, version:, actor:)
    uploads = Array(uploads).reject(&:blank?)
    raise ArgumentError, "Choose at least one photo" if uploads.empty?
    raise ArgumentError, "Use at most #{MAX_PHOTOS} photos per report" if Array(draft["photos"]).size + uploads.size > MAX_PHOTOS
    uploads.each do |upload|
      unless upload.respond_to?(:tempfile) && upload.size <= 10.megabytes &&
          %w[image/jpeg image/png image/webp].include?(Marcel::MimeType.for(upload.tempfile))
        raise ArgumentError, "Use JPEG, PNG, or WebP images up to 10 MB each"
      end
      begin
        image = Vips::Image.new_from_file(upload.tempfile.path, access: :sequential, fail_on: :warning)
        raise ArgumentError, "Photos must be no larger than 40 megapixels" if image.width * image.height > 40_000_000
        image.avg # Decode before saving so a damaged file cannot break the public gallery.
      rescue Vips::Error
        raise ArgumentError, "This image could not be read. Choose a valid JPEG, PNG, or WebP photo"
      end
    end
    with_lock do
      check_version!(version)
      ids_before = photos.map(&:id)
      photos.attach(uploads)
      additions = photos_attachments.reload.reject { |photo| ids_before.include?(photo.id) }.map { |photo| { "id" => photo.id, "caption" => "" } }
      # The first photo is the cover, so a new upload replaces the card thumbnail.
      update!(draft: draft.merge("photos" => additions + Array(draft["photos"])), last_edited_by: actor)
    end
  end

  private

  def valid_draft
    unless draft.is_a?(Hash)
      errors.add(:draft, "must be an object")
      return
    end
    unless FIELDS.excluding("photos").all? { |field| draft[field].nil? || draft[field].is_a?(String) }
      errors.add(:draft, "text fields must contain text")
      return
    end
    errors.add(:title, "can't be blank") if draft["title"].blank?
    %w[title location byline].each { |field| errors.add(field, "is too long") if draft[field].to_s.length > 250 }
    errors.add(:body, "is too long") if draft["body"].to_s.length > 100_000
    begin
      start_date = Date.iso8601(draft["start_date"].to_s)
      end_date = Date.iso8601(draft["end_date"].presence || draft["start_date"].to_s)
      errors.add(:end_date, "must be on or after the start date") if end_date < start_date
    rescue Date::Error
      errors.add(:start_date, "and end date must be valid dates")
    end
    errors.add(:trip_type, "is invalid") unless Trip::TRIP_TYPES.include?(draft["trip_type"])
    errors.add(:album_url, "must be an HTTPS Google Photos album link") if draft["album_url"].present? && !self.class.google_album?(draft["album_url"])
    entries = draft["photos"] || []
    unless entries.is_a?(Array) && entries.size <= MAX_PHOTOS && entries.all? { |photo| photo.is_a?(Hash) && photo["id"].is_a?(Integer) && photo["caption"].to_s.length <= 500 }
      errors.add(:photos, "must be a list of up to #{MAX_PHOTOS} photos with short captions")
      return
    end
    ids = entries.map { |photo| photo["id"] }
    errors.add(:photos, "must belong to this report and cannot be repeated") unless ids.uniq == ids && (ids - photos.map(&:id)).empty?
  end
end
