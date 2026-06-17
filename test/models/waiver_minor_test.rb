require "test_helper"

class WaiverMinorTest < ActiveSupport::TestCase
  test "validates minor details" do
    waiver = Waiver.create!(
      user: users(:sam),
      waiver_year: Date.current.year,
      waiver_type: "trip_minor",
      waiver_signed_at: Time.current
    )
    minor = waiver.waiver_minors.build(first_name: "Mika", last_name: "Lee", age: 18, relationship: "Child")

    assert_not minor.valid?
    assert_includes minor.errors[:age], "must be less than 18"
  end
end
