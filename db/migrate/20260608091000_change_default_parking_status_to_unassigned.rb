class ChangeDefaultParkingStatusToUnassigned < ActiveRecord::Migration[8.1]
  def up
    change_column_default :campsite_signups, :parking_status, from: "first_come_first_serve", to: "unassigned"
    execute <<~SQL.squish
      UPDATE campsite_signups
      SET parking_status = 'unassigned'
      WHERE parking_status = 'first_come_first_serve'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE campsite_signups
      SET parking_status = 'first_come_first_serve'
      WHERE parking_status = 'unassigned'
    SQL
    change_column_default :campsite_signups, :parking_status, from: "unassigned", to: "first_come_first_serve"
  end
end
