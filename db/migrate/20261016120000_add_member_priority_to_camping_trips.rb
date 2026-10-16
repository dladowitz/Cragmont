class AddMemberPriorityToCampingTrips < ActiveRecord::Migration[8.1]
  def up
    add_column :site_settings, :camping_member_priority_days, :integer, default: 15, null: false
    add_check_constraint :site_settings, "camping_member_priority_days BETWEEN 0 AND 365", name: "camping_member_priority_days_range"
    add_column :trips, :first_published_at, :datetime
    add_column :trips, :members_only_until, :datetime

    # Already-public trips retain open registration. Drafts get a window when published.
    execute <<~SQL
      UPDATE trips SET first_published_at = created_at
      WHERE status IN ('published', 'archived')
    SQL
  end

  def down
    remove_column :trips, :members_only_until
    remove_column :trips, :first_published_at
    remove_check_constraint :site_settings, name: "camping_member_priority_days_range"
    remove_column :site_settings, :camping_member_priority_days
  end
end
