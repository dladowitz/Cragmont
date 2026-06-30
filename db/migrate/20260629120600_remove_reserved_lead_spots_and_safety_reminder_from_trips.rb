class RemoveReservedLeadSpotsAndSafetyReminderFromTrips < ActiveRecord::Migration[8.1]
  def change
    remove_column :trips, :reserved_lead_spots, :integer if column_exists?(:trips, :reserved_lead_spots)
    remove_column :trips, :safety_reminder, :text if column_exists?(:trips, :safety_reminder)
  end
end
