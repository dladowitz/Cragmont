class AddRegistrationReimbursementToCampsites < ActiveRecord::Migration[8.0]
  def change
    add_column :campsites, :registration_fee_cents, :integer, null: false, default: 0
    add_column :campsites, :registration_reimbursed_at, :datetime
    add_reference :campsites, :registration_reimbursed_by, foreign_key: { to_table: :users }
    add_column :campsites, :registration_reimbursement_method, :string
    add_reference :campsites, :registration_reimbursement_recorded_by, foreign_key: { to_table: :users }
    add_column :campsites, :registration_reimbursement_notes, :text
  end
end
