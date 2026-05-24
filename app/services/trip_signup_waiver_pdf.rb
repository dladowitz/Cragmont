require "stringio"

class TripSignupWaiverPdf
  def initialize(trip_signup:, signature_png:)
    @trip_signup = trip_signup
    @signature_png = signature_png
  end

  def render
    Prawn::Document.new(page_size: "LETTER", margin: 54) do |pdf|
      pdf.text "Cragmont Climbing Trip Waiver", size: 22, style: :bold
      pdf.move_down 18

      detail(pdf, "Trip", trip.name)
      detail(pdf, "Trip dates", "#{trip.start_date.to_fs(:long)} to #{trip.end_date.to_fs(:long)}")
      detail(pdf, "Participant", @trip_signup.user.full_name)
      detail(pdf, "Email", @trip_signup.user.email.presence || "None")
      detail(pdf, "Signed at", @trip_signup.waiver_signed_at.to_fs(:long))
      detail(pdf, "Signature digest", @trip_signup.waiver_signature_digest)
      detail(pdf, "Waiver digest", @trip_signup.waiver_text_digest)

      pdf.move_down 18
      pdf.text "Waiver Text", size: 14, style: :bold
      pdf.move_down 8
      pdf.text @trip_signup.waiver_text, size: 11, leading: 3

      pdf.move_down 24
      pdf.text "Signature", size: 14, style: :bold
      pdf.move_down 8
      pdf.bounding_box([ 0, pdf.cursor ], width: 300, height: 110) do
        pdf.stroke_bounds
        pdf.image StringIO.new(@signature_png), fit: [ 280, 90 ], position: :center, vposition: :center
      end
    end.render
  end

  private

  def trip
    @trip_signup.trip
  end

  def detail(pdf, label, value)
    pdf.text "#{label}: #{value}", size: 11
  end
end
