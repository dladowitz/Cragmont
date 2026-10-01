class CreateClimbingPartnerRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :climbing_partner_requests do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :climbing_partner_requests, %i[trip_id user_id], unique: true
  end
end
