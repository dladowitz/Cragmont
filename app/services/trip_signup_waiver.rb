class TripSignupWaiver
  MINOR_RESPONSIBILITY_TEXT = "I agree I am solely responsible for the safety of minors I bring on a Cragmont trip.".freeze

  ACKNOWLEDGEMENT_TEXT = <<~TEXT.strip.freeze
    I understand that the Cragmont Climbing Club is not a teaching or instructional organization and that it is my responsibility to provide for my own instruction in climbing techniques and safety.

    Fees I pay are for sharing campsite space, supplies and logistics in getting together. They are not for guidance or instruction in climbing.

    No member or guest of Cragmont is authorized to give formal guidance or instruction on behalf of the club.

    The club does not test or vet club members or guests on their knowledge of climbing techniques, gear or safety.

    #{MINOR_RESPONSIBILITY_TEXT}
  TEXT

  TEXT = <<~TEXT.strip.freeze
    Liability Release

    READ THIS DOCUMENT CAREFULLY BEFORE SIGNING.

    YOU ARE GIVING UP IMPORTANT LEGAL RIGHTS.

    Liability Release

    Agreement Not to Sue

    Indemnity Agreement

    Assumption of Risk

    By signing this document I agree to give up certain legal rights that I may have in the event I become injured while engaging in activities with the Cragmont Climbing Club. I wish to engage in rock climbing with Cragmont Climbing Club members and others who engage in rock climbing and mountaineering activities sponsored by the club. I understand that rock climbing and mountaineering are inherently dangerous activities that involve risk of serious injury or death. I understand that, although it is the goal of the Cragmont Climbing Club to always climb in a manner that is safe, injury is nevertheless possible. In order to participate in these activities, I agree to assume the risk of any injury that may occur, and I promise that I will not hold the Cragmont Climbing Club, its members and those associated with it responsible if I become injured.

    In addition, I release the Cragmont Climbing Club, its members and those associated with it from all claims I may have for injury or loss resulting from negligence or other acts or omissions of members or those associated with the Cragmont Climbing Club.

    I understand that the Cragmont Climbing Club is not a teaching or instructional organization and that it is my responsibility to provide for my own instruction in climbing techniques and safety.

    I promise that I will carefully follow all instruction provided by members or those associated with the Cragmont Climbing Club, and will do everything possible to avoid injury to myself and others. I further agree to defend and pay all costs and expenses that the Cragmont Climbing Club, its members and those associated with it may incur as a consequence of any legal action arising out of injury to myself or injury to someone else as a result of my act or omission. I state that I am currently covered by medical insurance for any injuries that may occur to me while participating in Cragmont Climbing Club activities. I promise to never participate in Cragmont Climbing Club activities if I am not covered by this or similar medical insurance.

    #{MINOR_RESPONSIBILITY_TEXT}

    Finally, I intend for this document to apply not only to myself, but to anyone acting on my behalf.
  TEXT

  def self.text(includes_minors: false)
    TEXT
  end

  def self.acknowledgement_text(includes_minors: false)
    ACKNOWLEDGEMENT_TEXT
  end

  def self.acknowledgement_blocks(includes_minors: false)
    blocks_from(acknowledgement_text(includes_minors:))
  end

  def self.blocks(includes_minors: false)
    blocks_from(text(includes_minors:))
  end

  def self.blocks_from(text)
    text.to_s.split(/\n{2,}/).map(&:strip)
  end

  def self.title_block?(index, includes_minors: false)
    index.zero?
  end

  def self.warning_block?(index, includes_minors: false)
    [ 1, 2 ].include?(index)
  end

  def self.summary_heading_block?(index, includes_minors: false)
    (3..6).cover?(index)
  end

  def self.minor_responsibility_block?(block)
    block == MINOR_RESPONSIBILITY_TEXT
  end
end
