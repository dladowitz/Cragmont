require "test_helper"

class WaiverSignatureDataTest < ActiveSupport::TestCase
  test "accepts png data urls" do
    signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)

    assert signature.valid?
    assert signature.bytes.start_with?(WaiverSignatureData::PNG_SIGNATURE)
    assert_equal ::Digest::SHA256.hexdigest(signature.bytes), signature.digest
  end

  test "rejects blank data" do
    assert_not WaiverSignatureData.new("").valid?
  end

  test "rejects malformed data urls" do
    assert_not WaiverSignatureData.new("not-a-data-url").valid?
    assert_not WaiverSignatureData.new("data:image/png;base64,%%%").valid?
  end

  test "rejects non png data urls" do
    signature = WaiverSignatureData.new("data:image/png;base64,#{Base64.strict_encode64("hello")}")

    assert_not signature.valid?
  end
end
