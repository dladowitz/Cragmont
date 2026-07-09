class AddStripeProcessingFeeToCampsiteSignupPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :campsite_signup_payments, :stripe_processing_fee_cents, :integer
  end
end
