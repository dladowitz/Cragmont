class AddRefundedByToCampsiteSignupPaymentRefunds < ActiveRecord::Migration[8.0]
  def change
    add_reference :campsite_signup_payment_refunds,
      :refunded_by,
      foreign_key: { to_table: :users },
      index: true,
      null: true
  end
end
