class UpdateDayTripSignupSharedGearFields < ActiveRecord::Migration[8.1]
  def change
    remove_column :day_trip_signups, :rope, :boolean, null: false, default: false if column_exists?(:day_trip_signups, :rope)
    remove_column :day_trip_signups, :rope_length, :string if column_exists?(:day_trip_signups, :rope_length)

    add_column :day_trip_signups, :rope_60m, :boolean, null: false, default: false unless column_exists?(:day_trip_signups, :rope_60m)
    add_column :day_trip_signups, :rope_70m, :boolean, null: false, default: false unless column_exists?(:day_trip_signups, :rope_70m)
    add_column :day_trip_signups, :crash_pad_count, :integer, null: false, default: 0 unless column_exists?(:day_trip_signups, :crash_pad_count)
  end
end
