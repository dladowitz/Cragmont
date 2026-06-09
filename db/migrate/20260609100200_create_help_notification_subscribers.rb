class CreateHelpNotificationSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :help_notification_subscribers do |t|
      t.string :email, null: false

      t.timestamps
    end

    add_index :help_notification_subscribers, "lower(email)", unique: true, name: "index_help_notification_subscribers_on_lower_email"
  end
end
