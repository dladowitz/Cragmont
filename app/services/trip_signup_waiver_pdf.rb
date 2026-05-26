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
      detail(pdf, "Acknowledged at", @trip_signup.waiver_acknowledged_at.to_fs(:long))
      detail(pdf, "Signed at", @trip_signup.waiver_signed_at.to_fs(:long))
      detail(pdf, "Signature digest", @trip_signup.waiver_signature_digest)
      detail(pdf, "Acknowledgement digest", @trip_signup.waiver_acknowledgement_text_digest)
      detail(pdf, "Waiver digest", @trip_signup.waiver_text_digest)

      pdf.move_down 18
      render_acknowledgement_text(pdf)
      pdf.move_down 4
      render_waiver_text(pdf)

      pdf.start_new_page
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

  def render_acknowledgement_text(pdf)
    pdf.fill_color "1f2933"
    pdf.text "Plain-Language Acknowledgement", size: 14, style: :bold
    pdf.move_down 8
    TripSignupWaiver.acknowledgement_blocks.each do |block|
      pdf.text block, size: 11, leading: 4
      pdf.move_down 8
    end
  end

  def render_waiver_text(pdf)
    TripSignupWaiver.blocks.each_with_index do |block, index|
      if TripSignupWaiver.title_block?(index)
        pdf.fill_color "40512b"
        pdf.text block, size: 22, style: :bold, align: :center
      elsif TripSignupWaiver.warning_block?(index)
        pdf.fill_color "40512b"
        pdf.text block, size: 12, align: :center
      elsif TripSignupWaiver.summary_heading_block?(index)
        pdf.fill_color "40512b"
        pdf.text block, size: 16, style: :bold, align: :center
      else
        pdf.fill_color "40512b"
        pdf.text block, size: 10.5, leading: 5
      end
      pdf.move_down 14
    end
    pdf.fill_color "000000"
  end
end
