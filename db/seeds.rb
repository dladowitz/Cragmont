# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Role.seed_defaults!
TripDetailsEmailTemplate.ensure_defaults!

ENV.fetch("CRAGMONT_SUPER_ADMIN_EMAILS", "").split(",").map(&:strip).reject(&:blank?).each do |email|
  user = User.find_by(email: email)
  next if user.blank?

  user.roles << Role.find_by!(slug: "super_admin") unless user.super_admin?
end
