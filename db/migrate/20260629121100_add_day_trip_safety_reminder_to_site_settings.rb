class AddDayTripSafetyReminderToSiteSettings < ActiveRecord::Migration[8.1]
  DEFAULT_DAY_TRIP_SAFETY_REMINDER = "Climbing is dangerous. Everyone is responsible for checking their own knots, belay setup, anchors, gear, and decisions at the crag."

  def change
    add_column :site_settings,
      :day_trip_safety_reminder,
      :text,
      null: false,
      default: DEFAULT_DAY_TRIP_SAFETY_REMINDER
  end
end
