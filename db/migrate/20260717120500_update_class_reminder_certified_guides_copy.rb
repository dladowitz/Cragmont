class UpdateClassReminderCertifiedGuidesCopy < ActiveRecord::Migration[8.0]
  OLD_COPY = "Classes are run by other certified guiding companies"
  NEW_COPY = "Classes are run by certified guiding companies"

  def up
    execute <<~SQL.squish
      UPDATE content_pages
      SET body = REPLACE(body, #{quote(OLD_COPY)}, #{quote(NEW_COPY)}),
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'class_reminder'
        AND body LIKE #{quote("%#{OLD_COPY}%")}
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE content_pages
      SET body = REPLACE(body, #{quote(NEW_COPY)}, #{quote(OLD_COPY)}),
          updated_at = CURRENT_TIMESTAMP
      WHERE slug = 'class_reminder'
        AND body LIKE #{quote("%#{NEW_COPY}%")}
    SQL
  end
end
