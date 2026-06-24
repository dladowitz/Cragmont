class AddTripPhotoAlbumToYosemiteTemplate < ActiveRecord::Migration[8.1]
  class TripDetailsEmailTemplate < ActiveRecord::Base
  end

  TRIP_PHOTO_ALBUM_SECTION = <<~MARKDOWN.strip
    ## Trip Photo Album

    There is a trip photo album here: [{{photo_album_url}}]({{photo_album_url}}). We'd love to see what adventures you get up to.
    Post photos you want to share to it. The photos will automatically get posted to the club Past Trips page: https://www.cragmontclimbingclub.org/past-trips

    If you don't want any photos of you posted on the site let the Campsite Coordinator know and they'll review any uploaded photos.
  MARKDOWN

  WEATHER_SECTION = <<~MARKDOWN.strip
    ## Weather

    Trip weather link: [{{weather_url}}]({{weather_url}})
  MARKDOWN

  def up
    TripDetailsEmailTemplate.where(name: "Yosemite", area_key: "yosemite").find_each do |template|
      body = template.body_markdown.to_s
      next if body.include?("## Trip Photo Album")

      template.update!(body_markdown: insert_photo_album_section(body))
    end
  end

  def down
    TripDetailsEmailTemplate.where(name: "Yosemite", area_key: "yosemite").find_each do |template|
      body = template.body_markdown.to_s
      next unless body.include?(TRIP_PHOTO_ALBUM_SECTION)

      template.update!(body_markdown: body.gsub(/\n---\n\n#{Regexp.escape(TRIP_PHOTO_ALBUM_SECTION)}\n/, "\n"))
    end
  end

  private

  def insert_photo_album_section(body)
    section_with_dividers = "\n---\n\n#{TRIP_PHOTO_ALBUM_SECTION}\n"
    return "#{body}\n\n---\n\n#{TRIP_PHOTO_ALBUM_SECTION}" unless body.include?(WEATHER_SECTION)

    body.sub(WEATHER_SECTION, "#{WEATHER_SECTION}#{section_with_dividers}")
  end
end
