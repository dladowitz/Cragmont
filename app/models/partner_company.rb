class PartnerCompany < ApplicationRecord
  has_many :trips, dependent: :restrict_with_error

  validates :name, :website_url, :primary_contact_name, :primary_contact_phone, :primary_contact_email, presence: true
end
