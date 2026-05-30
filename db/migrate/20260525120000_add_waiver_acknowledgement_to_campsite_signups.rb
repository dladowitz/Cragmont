class AddWaiverAcknowledgementToCampsiteSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :campsite_signups, :waiver_acknowledged_at, :datetime
    add_column :campsite_signups, :waiver_acknowledgement_text, :text
    add_column :campsite_signups, :waiver_acknowledgement_text_digest, :string

    add_index :campsite_signups, :waiver_acknowledged_at
    add_index :campsite_signups, :waiver_acknowledgement_text_digest
  end
end
