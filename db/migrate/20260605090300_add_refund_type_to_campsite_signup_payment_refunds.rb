class AddRefundTypeToCampsiteSignupPaymentRefunds < ActiveRecord::Migration[8.0]
  def change
    add_column :campsite_signup_payment_refunds, :refund_type, :string, null: false, default: "automatic"
    add_index :campsite_signup_payment_refunds, :refund_type
  end
end
