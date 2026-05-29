require "test_helper"

class TripSignupWaiverTest < ActiveSupport::TestCase
  test "minor responsibility text is always included at the end of the acknowledgement" do
    assert_includes TripSignupWaiver.acknowledgement_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_equal TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT, TripSignupWaiver.acknowledgement_blocks.last
  end

  test "minor responsibility text is always included near the end of the waiver" do
    assert_includes TripSignupWaiver.text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_includes TripSignupWaiver.text(includes_minors: true), TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT

    blocks = TripSignupWaiver.blocks
    minor_index = blocks.index(TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT)
    final_index = blocks.index("Finally, I intend for this document to apply not only to myself, but to anyone acting on my behalf.")

    assert_equal final_index - 1, minor_index
  end
end
