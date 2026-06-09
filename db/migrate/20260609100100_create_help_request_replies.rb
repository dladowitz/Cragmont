class CreateHelpRequestReplies < ActiveRecord::Migration[8.1]
  def change
    create_table :help_request_replies do |t|
      t.references :help_request, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :message, null: false

      t.timestamps
    end
  end
end
