require "test_helper"

class TripSignupWaiverPdfTest < ActiveSupport::TestCase
  test "renders non empty pdf bytes" do
    signup = TripSignup.create!(trip: trips(:yosemite), user: users(:sam))
    attach_test_waiver_to(signup)
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)

    pdf = TripSignupWaiverPdf.new(trip_signup: signup, signature_png: signature.bytes).render

    assert pdf.start_with?("%PDF")
    assert_operator pdf.bytesize, :>, 1_000
  end
end
