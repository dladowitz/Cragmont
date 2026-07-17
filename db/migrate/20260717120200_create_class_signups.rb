class CreateClassSignups < ActiveRecord::Migration[8.0]
  def change
    create_table :class_signups do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "confirmed"

      t.timestamps
    end

    add_index :class_signups, :status
    add_index :class_signups, [ :trip_id, :user_id ],
      unique: true,
      where: "status <> 'canceled'",
      name: "index_class_signups_on_active_trip_user"
  end
end
