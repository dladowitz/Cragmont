class LegacyTripReportImport
  def self.call
    TripReport.transaction do
      JSON.parse(Rails.root.join("db/data/legacy_trip_reports.json").read).each do |entry|
        key = entry.delete("legacy_key")
        TripReport.find_or_create_by!(legacy_key: key) do |report|
          report.draft = entry
          report.published = entry
          report.published_at = Time.current
        end
      end
    end
  end
end
