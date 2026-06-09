class AddSubjectToHelpRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :help_requests, :subject, :string, null: false, default: ""
  end
end
