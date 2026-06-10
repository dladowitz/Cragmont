class CreateWaivers < ActiveRecord::Migration[8.1]
  def change
    create_table :waivers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trip, foreign_key: true
      t.references :campsite_signup, foreign_key: { on_delete: :nullify }
      t.integer :waiver_year, null: false
      t.string :waiver_type, null: false
      t.datetime :waiver_acknowledged_at
      t.text :waiver_acknowledgement_text
      t.string :waiver_acknowledgement_text_digest
      t.datetime :waiver_signed_at, null: false
      t.string :waiver_signer_name
      t.text :waiver_text
      t.string :waiver_text_digest
      t.string :waiver_signature_digest
      t.string :waiver_ip_address
      t.string :waiver_user_agent

      t.timestamps
    end

    add_index :waivers, [ :user_id, :waiver_year ]
    add_index :waivers, :waiver_type
    add_index :waivers, :waiver_signed_at
    add_index :waivers, :waiver_text_digest
    add_index :waivers, :waiver_signature_digest

    add_reference :campsite_signups, :waiver, foreign_key: true

    reversible do |dir|
      dir.up { backfill_existing_signup_waivers }
    end
  end

  private

  def backfill_existing_signup_waivers
    say_with_time "Backfilling existing campsite signup waivers" do
      rows = select_all(<<~SQL.squish)
        SELECT
          campsite_signups.*,
          trips.start_date AS trip_start_date,
          EXISTS (
            SELECT 1
            FROM campsite_signup_minors
            WHERE campsite_signup_minors.campsite_signup_id = campsite_signups.id
          ) AS includes_minors
        FROM campsite_signups
        INNER JOIN trips ON trips.id = campsite_signups.trip_id
        WHERE campsite_signups.waiver_signed_at IS NOT NULL
      SQL

      rows.each do |row|
        waiver_id = insert_waiver_for(row)
        execute(sanitize_sql([ "UPDATE campsite_signups SET waiver_id = ? WHERE id = ?", waiver_id, row.fetch("id") ]))
        copy_active_storage_attachment(row.fetch("id"), waiver_id, "waiver_document", "document")
        copy_active_storage_attachment(row.fetch("id"), waiver_id, "waiver_signature_image", "signature_image")
      end

      rows.rows.size
    end
  end

  def insert_waiver_for(row)
    now = quoted_current_time
    waiver_year = Date.parse(row.fetch("trip_start_date").to_s).year
    waiver_type = truthy?(row.fetch("includes_minors")) ? "trip_minor" : "annual_adult"

    insert(<<~SQL.squish)
      INSERT INTO waivers (
        user_id,
        trip_id,
        campsite_signup_id,
        waiver_year,
        waiver_type,
        waiver_acknowledged_at,
        waiver_acknowledgement_text,
        waiver_acknowledgement_text_digest,
        waiver_signed_at,
        waiver_signer_name,
        waiver_text,
        waiver_text_digest,
        waiver_signature_digest,
        waiver_ip_address,
        waiver_user_agent,
        created_at,
        updated_at
      )
      VALUES (
        #{q(row.fetch("user_id"))},
        #{q(row.fetch("trip_id"))},
        #{q(row.fetch("id"))},
        #{q(waiver_year)},
        #{q(waiver_type)},
        #{q(row["waiver_acknowledged_at"])},
        #{q(row["waiver_acknowledgement_text"])},
        #{q(row["waiver_acknowledgement_text_digest"])},
        #{q(row.fetch("waiver_signed_at"))},
        #{q(row["waiver_signer_name"])},
        #{q(row["waiver_text"])},
        #{q(row["waiver_text_digest"])},
        #{q(row["waiver_signature_digest"])},
        #{q(row["waiver_ip_address"])},
        #{q(row["waiver_user_agent"])},
        #{now},
        #{now}
      )
    SQL
  end

  def copy_active_storage_attachment(old_record_id, waiver_id, old_name, new_name)
    execute(<<~SQL.squish)
      INSERT INTO active_storage_attachments (
        name,
        record_type,
        record_id,
        blob_id,
        created_at
      )
      SELECT
        #{q(new_name)},
        'Waiver',
        #{q(waiver_id)},
        blob_id,
        #{quoted_current_time}
      FROM active_storage_attachments
      WHERE record_type = 'CampsiteSignup'
        AND record_id = #{q(old_record_id)}
        AND name = #{q(old_name)}
    SQL
  end

  def quoted_current_time
    q(Time.current)
  end

  def q(value)
    connection.quote(value)
  end

  def truthy?(value)
    value == true || value.to_s == "t" || value.to_s == "true" || value.to_s == "1"
  end

  def sanitize_sql(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
