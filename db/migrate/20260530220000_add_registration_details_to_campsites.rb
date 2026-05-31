class AddRegistrationDetailsToCampsites < ActiveRecord::Migration[8.0]
  def change
    add_reference :campsites, :registered_by, foreign_key: { to_table: :users }
    add_column :campsites, :registration_number, :string
  end
end
