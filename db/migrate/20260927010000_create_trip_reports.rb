class CreateTripReports < ActiveRecord::Migration[8.1]
  def change
    # Existing albums remain member-only; only newly created trips opt in by default.
    add_column :trips, :auto_trip_report, :boolean, default: false, null: false
    change_column_default :trips, :auto_trip_report, from: false, to: true

    create_table :trip_reports do |t|
      t.references :trip, foreign_key: true, index: { unique: true }
      t.string :legacy_key
      t.jsonb :draft, default: {}, null: false
      t.jsonb :published, default: {}, null: false
      t.datetime :published_at
      t.boolean :hidden, default: false, null: false
      t.references :last_edited_by, foreign_key: { to_table: :users }
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    add_index :trip_reports, :legacy_key, unique: true
  end
end
