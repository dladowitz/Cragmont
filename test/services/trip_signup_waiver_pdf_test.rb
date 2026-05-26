require "test_helper"

class TripSignupWaiverPdfTest < ActiveSupport::TestCase
  test "renders non empty pdf bytes" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    attach_test_waiver_to(signup)
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)

    pdf = TripSignupWaiverPdf.new(trip_signup: signup, signature_png: signature.bytes).render

    assert pdf.start_with?("%PDF")
    assert_operator pdf.bytesize, :>, 1_000
    assert_match(/\/Count [2-9]\b/, pdf)
  end

  test "formats metadata times in twelve hour Pacific time" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)
    service = TripSignupWaiverPdf.new(trip_signup: signup, signature_png: signature.bytes)

    formatted_time = service.send(:formatted_metadata_time, Time.utc(2026, 5, 27, 1, 4))

    assert_equal "May 26, 2026 6:04 PM PDT", formatted_time
  end
end
