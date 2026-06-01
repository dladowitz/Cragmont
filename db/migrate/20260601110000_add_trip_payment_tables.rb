class AddTripPaymentTables < ActiveRecord::Migration[8.1]
  def change
    rename_column :site_settings, :campsite_weekend_fee_cents, :first_two_nights_fee_cents
    rename_column :site_settings, :campsite_extra_night_fee_cents, :extra_night_fee_cents

    remove_index :campsite_signups, name: "index_campsite_signups_on_trip_id_and_user_id"
    add_index :campsite_signups,
      [ :trip_id, :user_id ],
      unique: true,
      where: "status != 'canceled'",
      name: "index_campsite_signups_on_active_trip_user"

    create_table :campsite_signup_payments do |t|
      t.references :campsite_signup, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :source, null: false, default: "stripe"
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "usd"
      t.integer :refunded_amount_cents, null: false, default: 0
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.text :checkout_url
      t.datetime :expires_at
      t.datetime :paid_at
      t.datetime :expired_at
      t.string :manual_payment_method
      t.datetime :manual_paid_at
      t.text :waived_reason
      t.text :note
      t.string :previous_signup_status
      t.jsonb :pricing_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :campsite_signup_payments, :status
    add_index :campsite_signup_payments, :source
    add_index :campsite_signup_payments,
      :stripe_checkout_session_id,
      unique: true,
      where: "stripe_checkout_session_id IS NOT NULL",
      name: "index_campsite_signup_payments_on_stripe_session"
    add_index :campsite_signup_payments, :stripe_payment_intent_id

    create_table :campsite_signup_payment_refunds do |t|
      t.references :campsite_signup_payment, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.string :source, null: false, default: "stripe"
      t.string :stripe_refund_id
      t.string :stripe_status
      t.text :failure_reason
      t.text :reason
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :campsite_signup_payment_refunds, :status
    add_index :campsite_signup_payment_refunds,
      :stripe_refund_id,
      unique: true,
      where: "stripe_refund_id IS NOT NULL",
      name: "index_campsite_signup_payment_refunds_on_stripe_refund"

    create_table :trip_reimbursements do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.string :recipient_name, null: false
      t.integer :amount_cents, null: false
      t.string :payment_method, null: false
      t.date :paid_on, null: false
      t.text :note

      t.timestamps
    end

    add_index :trip_reimbursements, :paid_on
  end
end
