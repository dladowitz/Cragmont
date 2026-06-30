class CreateDayTripSignups < ActiveRecord::Migration[8.1]
  def up
    drop_table :trip_signup_minors, if_exists: true
    drop_table :trip_signups, if_exists: true

    create_table :day_trip_signups do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :guest_of_day_trip_signup, foreign_key: { to_table: :day_trip_signups }
      t.integer :guest_position
      t.string :status, null: false, default: "confirmed"
      t.text :climbing_abilities
      t.boolean :rope_60m, null: false, default: false
      t.boolean :rope_70m, null: false, default: false
      t.boolean :quickdraws_and_sport_anchor, null: false, default: false
      t.boolean :clip_stick, null: false, default: false
      t.boolean :cams_nuts_and_trad_anchor, null: false, default: false
      t.integer :crash_pad_count, null: false, default: 0
      t.datetime :waiver_acknowledged_at
      t.text :waiver_acknowledgement_text
      t.string :waiver_acknowledgement_text_digest
      t.datetime :waiver_signed_at
      t.string :waiver_signer_name
      t.text :waiver_text
      t.string :waiver_text_digest
      t.string :waiver_signature_digest
      t.string :waiver_ip_address
      t.string :waiver_user_agent
      t.timestamps
    end

    add_index :day_trip_signups,
      [ :trip_id, :user_id ],
      unique: true,
      name: "index_day_trip_signups_on_active_trip_user",
      where: "status <> 'canceled'"
    add_index :day_trip_signups, :status
    add_index :day_trip_signups,
      [ :guest_of_day_trip_signup_id, :guest_position ],
      name: "index_day_trip_signups_on_guest_signup_position",
      where: "guest_of_day_trip_signup_id IS NOT NULL"

    create_table :day_trip_signup_minors do |t|
      t.references :day_trip_signup, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :age, null: false
      t.string :relationship, null: false
      t.timestamps
    end

    add_index :day_trip_signup_minors, :age
  end

  def down
    drop_table :day_trip_signup_minors, if_exists: true
    drop_table :day_trip_signups, if_exists: true

    create_table :trip_signups do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "confirmed"
      t.datetime :waiver_acknowledged_at
      t.text :waiver_acknowledgement_text
      t.string :waiver_acknowledgement_text_digest
      t.datetime :waiver_signed_at
      t.string :waiver_signer_name
      t.text :waiver_text
      t.string :waiver_text_digest
      t.string :waiver_signature_digest
      t.string :waiver_ip_address
      t.string :waiver_user_agent
      t.timestamps
    end

    add_index :trip_signups, [ :trip_id, :user_id ], unique: true
    add_index :trip_signups, :status

    create_table :trip_signup_minors do |t|
      t.references :trip_signup, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :age, null: false
      t.string :relationship, null: false
      t.timestamps
    end

    add_index :trip_signup_minors, :age
  end
end
