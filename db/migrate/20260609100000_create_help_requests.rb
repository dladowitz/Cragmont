class CreateHelpRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :help_requests do |t|
      t.references :user, foreign_key: true
      t.string :reason, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.string :status, null: false, default: "open"
      t.datetime :last_replied_at

      t.timestamps
    end

    add_index :help_requests, :email
    add_index :help_requests, :reason
    add_index :help_requests, :status
  end
end
