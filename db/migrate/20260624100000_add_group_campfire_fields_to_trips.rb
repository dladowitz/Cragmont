class AddGroupCampfireFieldsToTrips < ActiveRecord::Migration[8.1]
  OLD_GROUP_CAMPFIRE_TEXT = "We'll have a group campfire at **<Site X>** on Saturday evening.".freeze
  NEW_GROUP_CAMPFIRE_TEXT = "{{group_campfire_info}}".freeze

  class TripDetailsEmailTemplate < ActiveRecord::Base
    self.table_name = "trip_details_email_templates"
  end

  def up
    add_reference :trips, :group_campfire_campsite, foreign_key: { to_table: :campsites }
    add_column :trips, :group_fire_night, :string

    TripDetailsEmailTemplate.where(name: "Yosemite", area_key: "yosemite").find_each do |template|
      next unless template.body_markdown.to_s.include?(OLD_GROUP_CAMPFIRE_TEXT)

      template.update_columns(
        body_markdown: template.body_markdown.gsub(OLD_GROUP_CAMPFIRE_TEXT, NEW_GROUP_CAMPFIRE_TEXT),
        updated_at: Time.current
      )
    end
  end

  def down
    TripDetailsEmailTemplate.where(name: "Yosemite", area_key: "yosemite").find_each do |template|
      next unless template.body_markdown.to_s.include?(NEW_GROUP_CAMPFIRE_TEXT)

      template.update_columns(
        body_markdown: template.body_markdown.gsub(NEW_GROUP_CAMPFIRE_TEXT, OLD_GROUP_CAMPFIRE_TEXT),
        updated_at: Time.current
      )
    end

    remove_column :trips, :group_fire_night
    remove_reference :trips, :group_campfire_campsite, foreign_key: { to_table: :campsites }
  end
end
