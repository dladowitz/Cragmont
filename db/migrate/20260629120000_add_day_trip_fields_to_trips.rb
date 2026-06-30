class AddDayTripFieldsToTrips < ActiveRecord::Migration[8.1]
  DEFAULT_LATE_ARRIVAL_INSTRUCTIONS = "If you are running late here is the general area we'll be climbing at ...".freeze

  def change
    add_column :trips, :trip_type, :string, default: "camping", null: false unless column_exists?(:trips, :trip_type)
    add_column :trips, :meeting_time, :time unless column_exists?(:trips, :meeting_time)
    add_column :trips, :meeting_location, :string unless column_exists?(:trips, :meeting_location)
    add_column :trips, :meeting_location_url, :text unless column_exists?(:trips, :meeting_location_url)
    add_column :trips, :late_arrival_instructions, :text, default: DEFAULT_LATE_ARRIVAL_INSTRUCTIONS, null: false unless column_exists?(:trips, :late_arrival_instructions)
    add_column :trips, :carpool_meeting_spot, :text unless column_exists?(:trips, :carpool_meeting_spot)
    add_column :trips, :end_time, :time unless column_exists?(:trips, :end_time)
    add_column :trips, :cost_cents, :integer, default: 0, null: false unless column_exists?(:trips, :cost_cents)
    add_column :trips, :participant_capacity, :integer, default: 0, null: false unless column_exists?(:trips, :participant_capacity)
    add_column :trips, :climbing_types, :text unless column_exists?(:trips, :climbing_types)
    add_column :trips, :mountain_project_url, :text unless column_exists?(:trips, :mountain_project_url)
    add_column :trips, :guide_book_url, :text unless column_exists?(:trips, :guide_book_url)

    add_index :trips, :trip_type unless index_exists?(:trips, :trip_type)
  end
end
