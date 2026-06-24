class CreateTripDetailsEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_details_email_templates do |t|
      t.string :name, null: false
      t.string :area_key, null: false
      t.string :subject_template, null: false
      t.text :body_markdown, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :trip_details_email_templates, :area_key
    add_index :trip_details_email_templates, [ :name, :area_key ], unique: true

    create_table :trip_details_emails do |t|
      t.references :trip, null: false, foreign_key: true, index: { unique: true }
      t.references :trip_details_email_template, null: false, foreign_key: true, index: { name: "idx_trip_details_emails_on_template_id" }
      t.string :status, null: false, default: "draft"
      t.string :subject, null: false
      t.text :body_markdown, null: false
      t.text :rendered_html_snapshot
      t.text :rendered_text_snapshot
      t.string :template_name_snapshot
      t.string :template_area_key_snapshot
      t.datetime :sent_at
      t.references :sent_by, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end

    add_index :trip_details_emails, :status

    create_table :trip_details_email_recipients do |t|
      t.references :trip_details_email, null: false, foreign_key: true, index: { name: "idx_trip_details_recipients_on_email_id" }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :campsite_signup, foreign_key: { on_delete: :nullify }, index: { name: "idx_trip_details_recipients_on_signup_id" }
      t.string :recipient_name, null: false
      t.string :email, null: false
      t.string :campsite_label, null: false
      t.string :delivery_status, null: false, default: "pending"
      t.datetime :delivered_at
      t.text :error_message

      t.timestamps
    end

    add_index :trip_details_email_recipients, :delivery_status, name: "idx_trip_details_recipients_on_delivery_status"
  end
end
