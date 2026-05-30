class AddWaiverFieldsToCampsiteSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :campsite_signups, :waiver_signed_at, :datetime
    add_column :campsite_signups, :waiver_signer_name, :string
    add_column :campsite_signups, :waiver_text, :text
    add_column :campsite_signups, :waiver_text_digest, :string
    add_column :campsite_signups, :waiver_signature_digest, :string
    add_column :campsite_signups, :waiver_ip_address, :string
    add_column :campsite_signups, :waiver_user_agent, :string

    add_index :campsite_signups, :waiver_signed_at
    add_index :campsite_signups, :waiver_text_digest
    add_index :campsite_signups, :waiver_signature_digest
  end
end
