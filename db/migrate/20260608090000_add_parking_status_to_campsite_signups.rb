class AddParkingStatusToCampsiteSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :campsite_signups, :parking_status, :string, null: false, default: "first_come_first_serve"
    add_index :campsite_signups,
      [ :campsite_id, :parking_status ],
      name: "index_campsite_signups_on_campsite_parking_status"
  end
end
