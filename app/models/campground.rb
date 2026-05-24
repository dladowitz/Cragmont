class Campground < ApplicationRecord
  has_many :campsites, dependent: :restrict_with_error

  validates :name, :location, presence: true
end
