class Role < ApplicationRecord
  SLUGS = %w[super_admin finance_admin trip_admin].freeze
  NAMES = {
    "super_admin" => "Super Admin",
    "finance_admin" => "Finance Admin",
    "trip_admin" => "Trip Admin"
  }.freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase }

  validates :name, :slug, presence: true
  validates :slug, inclusion: { in: SLUGS }, uniqueness: true

  def self.seed_defaults!
    NAMES.each do |slug, name|
      find_or_initialize_by(slug: slug).tap do |role|
        role.name = name
        role.save!
      end
    end
  end
end
