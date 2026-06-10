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
      {
        campsite_signup: {
          arrival_date: campsites(:yosemite_a).arrival_date.to_s,
          checkout_date: campsites(:yosemite_a).checkout_date.to_s,
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    def create_campsite_signup!(campsite:, user:, **attributes)
      CampsiteSignup.create!(
        {
          campsite: campsite,
          user: user,
          arrival_date: campsite.arrival_date,
          checkout_date: campsite.checkout_date
        }.merge(attributes)
      )
    end

    def create_waitlisted_signup!(trip:, user:, **attributes)
      CampsiteSignup.create!(
        {
          trip: trip,
          user: user,
          status: "waitlisted"
        }.merge(attributes)
      )
    end

    def log_in_as(user)
      post session_url, params: { email: user.email, password: "password" }
    end

    def assign_role(user, slug)
      user.roles << roles(slug) unless user.has_role?(slug.to_s)
      user.reload
    end

    def attach_test_waiver_to(signup)
      signature = WaiverSignatureData.new(SIGNATURE_DATA_URL)
      waiver_text = TripSignupWaiver.text
      acknowledgement_text = TripSignupWaiver.acknowledgement_text
      signed_at = Time.current

      waiver = Waiver.create!(
        user: signup.user,
        trip: signup.trip,
        campsite_signup: signup,
        waiver_year: signup.trip.start_date.year,
        waiver_type: signup.includes_minors? ? "trip_minor" : "annual_adult",
        waiver_acknowledged_at: signed_at,
        waiver_acknowledgement_text: acknowledgement_text,
        waiver_acknowledgement_text_digest: ::Digest::SHA256.hexdigest(acknowledgement_text),
        waiver_signed_at: signed_at,
        waiver_signer_name: signup.user.full_name,
        waiver_text: waiver_text,
        waiver_text_digest: ::Digest::SHA256.hexdigest(waiver_text),
        waiver_signature_digest: signature.digest,
        waiver_ip_address: "127.0.0.1",
        waiver_user_agent: "Rails test"
      )
      waiver.signature_image.attach(io: StringIO.new(signature.bytes), filename: "signature.png", content_type: "image/png")
      waiver.document.attach(
        io: StringIO.new(WaiverPdf.new(waiver: waiver, signature_png: signature.bytes).render),
        filename: waiver.document_filename,
        content_type: "application/pdf"
      )

      signup.update!(
        waiver: waiver,
        waiver_acknowledged_at: Time.current,
        waiver_acknowledgement_text: acknowledgement_text,
        waiver_acknowledgement_text_digest: ::Digest::SHA256.hexdigest(acknowledgement_text),
        waiver_signed_at: signed_at,
        waiver_signer_name: signup.user.full_name,
        waiver_text: waiver_text,
        waiver_text_digest: ::Digest::SHA256.hexdigest(waiver_text),
        waiver_signature_digest: signature.digest,
        waiver_ip_address: "127.0.0.1",
        waiver_user_agent: "Rails test"
      )
      signup.waiver_signature_image.attach(io: StringIO.new(signature.bytes), filename: "signature.png", content_type: "image/png")
      signup.waiver_document.attach(
        io: StringIO.new(CampsiteSignupWaiverPdf.new(campsite_signup: signup, signature_png: signature.bytes).render),
        filename: signup.waiver_document_filename,
        content_type: "application/pdf"
      )
      signup
    end
  end
end
