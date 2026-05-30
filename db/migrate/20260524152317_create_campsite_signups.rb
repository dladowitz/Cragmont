class CreateCampsiteSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :campsite_signups do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :campsite, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "confirmed"

      t.timestamps
    end

    add_index :campsite_signups, [ :trip_id, :user_id ], unique: true
    add_index :campsite_signups, :status
  end
end
