class AddCheckoutExpiresAtToCampsiteSignupPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :campsite_signup_payments, :checkout_expires_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE campsite_signup_payments
          SET checkout_expires_at = expires_at
        SQL
      end
    end
  end
end
