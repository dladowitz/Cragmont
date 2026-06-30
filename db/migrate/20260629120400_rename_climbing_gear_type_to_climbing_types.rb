class RenameClimbingGearTypeToClimbingTypes < ActiveRecord::Migration[8.1]
  def change
    if column_exists?(:trips, :climbing_gear_type) && !column_exists?(:trips, :climbing_types)
      rename_column :trips, :climbing_gear_type, :climbing_types
    end

    change_column :trips, :climbing_types, :text if column_exists?(:trips, :climbing_types)
  end
end
