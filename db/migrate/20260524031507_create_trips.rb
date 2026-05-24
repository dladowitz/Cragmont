class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.string :name, null: false
      t.string :location, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.text :description
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :trips, :status
    add_index :trips, :start_date
  end
end
