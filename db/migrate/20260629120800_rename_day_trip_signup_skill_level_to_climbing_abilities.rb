class RenameDayTripSignupSkillLevelToClimbingAbilities < ActiveRecord::Migration[8.1]
  def up
    if column_exists?(:day_trip_signups, :skill_level) && !column_exists?(:day_trip_signups, :climbing_abilities)
      rename_column :day_trip_signups, :skill_level, :climbing_abilities
    elsif !column_exists?(:day_trip_signups, :climbing_abilities)
      add_column :day_trip_signups, :climbing_abilities, :text
    end

    change_column :day_trip_signups, :climbing_abilities, :text if column_exists?(:day_trip_signups, :climbing_abilities)
  end

  def down
    if column_exists?(:day_trip_signups, :climbing_abilities) && !column_exists?(:day_trip_signups, :skill_level)
      rename_column :day_trip_signups, :climbing_abilities, :skill_level
    elsif !column_exists?(:day_trip_signups, :skill_level)
      add_column :day_trip_signups, :skill_level, :string
    end

    change_column_default :day_trip_signups, :skill_level, from: nil, to: "top_rope" if column_exists?(:day_trip_signups, :skill_level)
  end
end
