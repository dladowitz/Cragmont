class BackfillHelpRequestSubjects < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE help_requests
      SET subject = 'Help request'
      WHERE subject IS NULL OR subject = ''
    SQL

    change_column_default :help_requests, :subject, from: "", to: "Help request"
  end

  def down
    change_column_default :help_requests, :subject, from: "Help request", to: ""
  end
end
