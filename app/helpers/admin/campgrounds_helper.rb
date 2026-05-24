module Admin::CampgroundsHelper
  def campground_website_url(campground)
    uri = URI.parse(campground.website.to_s)
    return unless uri.is_a?(URI::HTTP)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
