class AddTripLevelWaitlistFields < ActiveRecord::Migration[8.1]
  def change
    add_column :campsites, :signups_locked_at, :datetime
    add_index :campsites, :signups_locked_at

    add_column :campsite_signups, :waitlist_eligible_at, :datetime
    add_index :campsite_signups, :waitlist_eligible_at

    change_column_null :campsite_signups, :campsite_id, true
    change_column_null :campsite_signups, :arrival_date, true
    change_column_null :campsite_signups, :checkout_date, true
  end
end
