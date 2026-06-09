class RemoveDefaultHelpRequestSubject < ActiveRecord::Migration[8.1]
  def change
    change_column_default :help_requests, :subject, from: "Help request", to: nil
  end
end
