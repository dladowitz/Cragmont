class ImportLegacyTripReports < ActiveRecord::Migration[8.1]
  def up
    # Import immutable archive data without depending on future application validations.
    report = Class.new(ActiveRecord::Base) { self.table_name = "trip_reports" }
    JSON.parse(File.read(Rails.root.join("db/data/legacy_trip_reports.json"))).each do |entry|
      key = entry.delete("legacy_key")
      report.find_or_create_by!(legacy_key: key) do |record|
        record.draft = entry
        record.published = entry
        record.published_at = Time.current
      end
    end
  end

  def down
    # Reports may have been edited or linked to trips; never erase them on rollback.
    raise ActiveRecord::IrreversibleMigration
  end
end
