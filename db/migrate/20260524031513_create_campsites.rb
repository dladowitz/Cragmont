class CreateCampsites < ActiveRecord::Migration[8.1]
  def change
    create_table :campsites do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :campground, null: false, foreign_key: true
      t.string :site_number, null: false
      t.date :arrival_date, null: false
      t.date :checkout_date, null: false
      t.integer :participant_capacity, null: false
      t.integer :car_capacity, null: false
      t.text :notes

      t.timestamps
    end

    add_index :campsites, :arrival_date
  end
end
