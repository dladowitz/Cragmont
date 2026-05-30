require "test_helper"

class CampsiteSignupWaiverPdfTest < ActiveSupport::TestCase
  test "renders non empty pdf bytes" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    attach_test_waiver_to(signup)
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)

    pdf = CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes).render

    assert pdf.start_with?("%PDF")
    assert_operator pdf.bytesize, :>, 1_000
    assert_match(/\/Count [2-9]\b/, pdf)
  end

  test "formats metadata times in twelve hour Pacific time" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)
    service = CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes)

    formatted_time = service.send(:formatted_metadata_time, Time.utc(2026, 5, 27, 1, 4))

    assert_equal "May 26, 2026 6:04 PM PDT", formatted_time
  end

  test "renders minor details into signed waiver pdf" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")
    attach_test_waiver_to(signup)
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)

    pdf = CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes).render

    assert pdf.start_with?("%PDF")
    assert_operator pdf.bytesize, :>, 1_000
    assert_includes signup.waiver_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_includes signup.waiver_acknowledgement_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
  end

  test "renders minor details as separate labeled lines" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    signup.campsite_signup_minors.create!(first_name: "Mika", last_name: "Lee", age: 12, relationship: "Child")
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)
    service = CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes)
    pdf = FakePdf.new

    service.send(:render_minors, pdf)

    assert_includes pdf.texts, "Minors covered by this waiver"
    assert_includes pdf.texts, "Name: Mika Lee"
    assert_includes pdf.texts, "Age: 12"
    assert_includes pdf.texts, "Relationship: child"
    refute_includes pdf.texts, "Minor: Mika Lee, age 12, Child"
  end

  class FakePdf
    attr_reader :texts

    def initialize
      @texts = []
    end

    def move_down(_amount)
    end

    def text(content, **)
      texts << content
    end
  end
end
