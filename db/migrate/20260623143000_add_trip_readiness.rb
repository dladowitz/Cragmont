class AddTripReadiness < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :photo_album_url, :text

    create_table :trip_readiness_completions do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :task_key, null: false
      t.datetime :completed_at, null: false
      t.references :completed_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :trip_readiness_completions,
      [ :trip_id, :task_key ],
      unique: true,
      name: "index_trip_readiness_completions_on_trip_and_task"
  end
end
