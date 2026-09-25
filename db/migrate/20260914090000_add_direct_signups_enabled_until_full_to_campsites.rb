class AddDirectSignupsEnabledUntilFullToCampsites < ActiveRecord::Migration[8.1]
  def change
    add_column :campsites, :direct_signups_enabled_until_full, :boolean, null: false, default: false
  end
end
