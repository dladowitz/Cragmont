class AddCheckoutExpiresAtToTripPaymentRequests < ActiveRecord::Migration[8.0]
  def up
    add_column :trip_payment_requests, :checkout_expires_at, :datetime

    execute <<~SQL.squish
      UPDATE trip_payment_requests
      SET checkout_expires_at = expires_at,
          expires_at = COALESCE(created_at, CURRENT_TIMESTAMP) + INTERVAL '30 days'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE trip_payment_requests
      SET expires_at = checkout_expires_at
      WHERE checkout_expires_at IS NOT NULL
    SQL

    remove_column :trip_payment_requests, :checkout_expires_at
  end
end
