class CreateCampsiteParkingSpots < ActiveRecord::Migration[8.1]
  def up
    create_table :campsite_parking_spots do |t|
      t.references :campsite, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :status, null: false, default: "unassigned"
      t.references :assigned_campsite_signup, index: false, foreign_key: { to_table: :campsite_signups }

      t.timestamps
    end

    add_index :campsite_parking_spots, [ :campsite_id, :position ], unique: true
    add_index :campsite_parking_spots,
      :assigned_campsite_signup_id,
      unique: true,
      where: "assigned_campsite_signup_id IS NOT NULL",
      name: "index_parking_spots_on_assigned_signup"

    say_with_time "Creating empty campsite parking spots" do
      rows = select_all("SELECT id, car_capacity, created_at, updated_at FROM campsites").flat_map do |campsite|
        capacity = campsite.fetch("car_capacity").to_i
        (1..capacity).map do |position|
          {
            campsite_id: campsite.fetch("id"),
            position: position,
            status: "unassigned",
            created_at: campsite.fetch("created_at"),
            updated_at: campsite.fetch("updated_at")
          }
        end
      end

      CampsiteParkingSpot.insert_all(rows) if rows.any?
      rows.size
    end

    remove_index :campsite_signups, name: "index_campsite_signups_on_campsite_parking_status"
    remove_column :campsite_signups, :parking_status
  end

  def down
    add_column :campsite_signups, :parking_status, :string, null: false, default: "unassigned"
    add_index :campsite_signups,
      [ :campsite_id, :parking_status ],
      name: "index_campsite_signups_on_campsite_parking_status"

    drop_table :campsite_parking_spots
  end
end
