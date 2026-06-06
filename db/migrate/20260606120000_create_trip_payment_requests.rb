class CreateTripPaymentRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_payment_requests do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :canceled_by, foreign_key: { to_table: :users }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "usd"
      t.text :reason, null: false
      t.string :status, null: false, default: "pending"
      t.text :checkout_url
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.datetime :paid_at
      t.datetime :canceled_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :trip_payment_requests, :email
    add_index :trip_payment_requests, :status
    add_index :trip_payment_requests, :stripe_checkout_session_id,
      unique: true,
      where: "stripe_checkout_session_id IS NOT NULL",
      name: "index_trip_payment_requests_on_stripe_session"
    add_index :trip_payment_requests, :stripe_payment_intent_id
  end
end
