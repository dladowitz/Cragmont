class RemoveClassReminderDetailsHeading < ActiveRecord::Migration[8.0]
  HEADING_WITH_BLANK_LINE = "## Class Details\n\n"
  HEADING_ONLY = "## Class Details"

  def up
    execute <<~SQL
      UPDATE content_pages
      SET body = CASE
        WHEN body LIKE #{quote("#{HEADING_WITH_BLANK_LINE}%")}
          THEN SUBSTRING(body FROM #{HEADING_WITH_BLANK_LINE.length + 1})
        WHEN body = #{quote(HEADING_ONLY)}
          THEN ''
        WHEN body LIKE #{quote("#{HEADING_ONLY}\n%")}
          THEN SUBSTRING(body FROM #{HEADING_ONLY.length + 2})
        ELSE body
      END,
      updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'class_reminder'
        AND body LIKE #{quote("#{HEADING_ONLY}%")}
    SQL
  end

  def down
    execute <<~SQL
      UPDATE content_pages
      SET body = #{quote("#{HEADING_WITH_BLANK_LINE}")} || body,
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'class_reminder'
        AND body NOT LIKE #{quote("#{HEADING_ONLY}%")}
    SQL
  end
end
