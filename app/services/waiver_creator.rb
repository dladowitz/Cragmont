require "digest"
require "stringio"

class WaiverCreator
  def initialize(user:, signature:, acknowledged_at:, request:, trip: nil, campsite_signup: nil, waiver_year: nil, minor_attributes: [])
    @user = user
    @signature = signature
    @acknowledged_at = acknowledged_at
    @request = request
    @trip = trip || campsite_signup&.trip
    @campsite_signup = campsite_signup
    @waiver_year = waiver_year || @trip&.start_date&.year || Date.current.year
    @minor_attributes = minor_attributes
  end

  def create!
    waiver = nil

    Waiver.transaction do
      waiver = Waiver.create!(waiver_attributes)
      minor_attributes_for_waiver.each { |attributes| waiver.waiver_minors.create!(attributes) }
      attach_files!(waiver)
      sync_signup_legacy_waiver!(waiver) if @campsite_signup.present?
    end

    waiver
  end

  private

  def waiver_type
    includes_minors? ? "trip_minor" : "annual_adult"
  end

  def waiver_text
    @waiver_text ||= TripSignupWaiver.text(includes_minors: includes_minors?)
  end

  def acknowledgement_text
    @acknowledgement_text ||= TripSignupWaiver.acknowledgement_text(includes_minors: includes_minors?)
  end

  def includes_minors?
    minor_attributes_for_waiver.any?
  end

  def minor_attributes_for_waiver
    @minor_attributes_for_waiver ||= if @minor_attributes.present?
      @minor_attributes
    elsif @campsite_signup&.includes_minors?
      @campsite_signup.campsite_signup_minors.map do |minor|
        {
          first_name: minor.first_name,
          last_name: minor.last_name,
          age: minor.age,
          relationship: minor.relationship
        }
      end
    else
      []
    end
  end

  def waiver_attributes
    {
      user: @user,
      trip: @trip,
      campsite_signup: @campsite_signup,
      waiver_year: @waiver_year,
      waiver_type: waiver_type,
      waiver_acknowledged_at: @acknowledged_at,
      waiver_acknowledgement_text: acknowledgement_text,
      waiver_acknowledgement_text_digest: Digest::SHA256.hexdigest(acknowledgement_text),
      waiver_signed_at: Time.current,
      waiver_signer_name: @user.full_name,
      waiver_text: waiver_text,
      waiver_text_digest: Digest::SHA256.hexdigest(waiver_text),
      waiver_signature_digest: @signature.digest,
      waiver_ip_address: @request.remote_ip,
      waiver_user_agent: @request.user_agent
    }
  end

  def attach_files!(waiver)
    waiver.signature_image.attach(
      io: StringIO.new(@signature.bytes),
      filename: "waiver-#{waiver.id}-signature.png",
      content_type: "image/png"
    )

    @pdf_bytes = WaiverPdf.new(waiver: waiver, signature_png: @signature.bytes).render
    waiver.document.attach(
      io: StringIO.new(@pdf_bytes),
      filename: waiver.document_filename,
      content_type: "application/pdf"
    )
  end

  def sync_signup_legacy_waiver!(waiver)
    @campsite_signup.update!(
      waiver: waiver,
      waiver_acknowledged_at: waiver.waiver_acknowledged_at,
      waiver_acknowledgement_text: waiver.waiver_acknowledgement_text,
      waiver_acknowledgement_text_digest: waiver.waiver_acknowledgement_text_digest,
      waiver_signed_at: waiver.waiver_signed_at,
      waiver_signer_name: waiver.waiver_signer_name,
      waiver_text: waiver.waiver_text,
      waiver_text_digest: waiver.waiver_text_digest,
      waiver_signature_digest: waiver.waiver_signature_digest,
      waiver_ip_address: waiver.waiver_ip_address,
      waiver_user_agent: waiver.waiver_user_agent
    )

    @campsite_signup.waiver_signature_image.attach(
      io: StringIO.new(@signature.bytes),
      filename: "campsite-signup-#{@campsite_signup.id}-signature.png",
      content_type: "image/png"
    )

    @campsite_signup.waiver_document.attach(
      io: StringIO.new(@pdf_bytes),
      filename: @campsite_signup.waiver_document_filename,
      content_type: "application/pdf"
    )
  end
end
