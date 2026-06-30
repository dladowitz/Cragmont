class NormalizeClimbingTypesValues < ActiveRecord::Migration[8.1]
  CLIMBING_TYPES = %w[sport trad bouldering].freeze
  LEGACY_TYPE_MAP = {
    "sport" => [ "sport" ],
    "trad" => [ "trad" ],
    "both" => [ "sport", "trad" ]
  }.freeze

  def up
    return unless column_exists?(:trips, :climbing_types)

    say_with_time "Normalizing trip climbing types" do
      select_rows("SELECT id, climbing_types FROM trips").each do |id, raw_value|
        normalized_types = normalize_types(raw_value)
        update("UPDATE trips SET climbing_types = #{quote(normalized_types.to_json)} WHERE id = #{id}")
      end
    end
  end

  def down
    # The previous column format was ambiguous for multiple values, so keep the JSON array representation.
  end

  private

  def normalize_types(raw_value)
    raw_string = raw_value.to_s
    parsed_value = JSON.parse(raw_string)
    Array(parsed_value).map(&:to_s).select { |type| type.in?(CLIMBING_TYPES) }.uniq
  rescue JSON::ParserError
    LEGACY_TYPE_MAP.fetch(raw_string, [])
  end
end
