class AddInitiatedByToCampsiteSignupPaymentRefunds < ActiveRecord::Migration[8.0]
  def up
    add_column :campsite_signup_payment_refunds, :initiated_by, :string, null: false, default: "system"
    add_index :campsite_signup_payment_refunds, :initiated_by

    execute <<~SQL.squish
      UPDATE campsite_signup_payment_refunds
      SET initiated_by = CASE
        WHEN reason = 'requested_by_participant' THEN 'participant'
        WHEN reason IN ('removed_by_admin', 'moved_to_waitlist') THEN 'admin'
        ELSE 'system'
      END
    SQL
  end

  def down
    remove_index :campsite_signup_payment_refunds, :initiated_by
    remove_column :campsite_signup_payment_refunds, :initiated_by
  end
end
