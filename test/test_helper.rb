ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "digest"
require "stringio"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    SIGNATURE_DATA_URL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=".freeze

    def waiver_signature_params
      { trip_signup: { waiver_signature_data: SIGNATURE_DATA_URL, waiver_acknowledged_at: Time.current.iso8601 } }
    end

    def attach_test_waiver_to(signup)
      signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)
      waiver_text = TripSignupWaiver.text
      acknowledgement_text = TripSignupWaiver.acknowledgement_text

      signup.update!(
        waiver_acknowledged_at: Time.current,
        waiver_acknowledgement_text: acknowledgement_text,
        waiver_acknowledgement_text_digest: ::Digest::SHA256.hexdigest(acknowledgement_text),
        waiver_signed_at: Time.current,
        waiver_signer_name: signup.user.full_name,
        waiver_text: waiver_text,
        waiver_text_digest: ::Digest::SHA256.hexdigest(waiver_text),
        waiver_signature_digest: signature.digest,
        waiver_ip_address: "127.0.0.1",
        waiver_user_agent: "Rails test"
      )
      signup.waiver_signature_image.attach(io: StringIO.new(signature.bytes), filename: "signature.png", content_type: "image/png")
      signup.waiver_document.attach(
        io: StringIO.new(TripSignupWaiverPdf.new(trip_signup: signup, signature_png: signature.bytes).render),
        filename: signup.waiver_document_filename,
        content_type: "application/pdf"
      )
      signup
    end
  end
end
