class Api::V1::CampgroundsController < Api::V1::BaseController
  def index
    authorize Trip, :index?
    render json: { campgrounds: Campground.order(:name).as_json(only: %i[id name location website]) }
  end

  def create
    campground = Campground.new(permitted_payload(:campground, :name, :location, :website, :notes))
    authorize campground
    if campground.save
      render json: { campground: campground.as_json(only: %i[id name location website notes]) }, status: :created
    else
      validation_error(campground)
    end
  end
end
