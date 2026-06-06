class DropTripReimbursements < ActiveRecord::Migration[8.0]
  def up
    drop_table :trip_reimbursements, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
