module Ui
  class BadgeComponent < BaseComponent
    TEMPLATE = "ui/badge"
    TONES = {
      neutral: nil, success: "success-status", warning: "warning-status", danger: "danger-status",
      draft: "draft-status", archived: "archived-status", open: "open-status",
      replied: "replied-status", resolved: "resolved-status", day_trip: "day-trip-badge",
      gym_outing: "gym-outing-badge", external_class: "external-class-badge"
    }.freeze

    def initialize(text: nil, tone: :neutral, pill: false, **attributes)
      super(text: text, **attributes)
      option!(tone, TONES.keys, :badge_tone)
      add_classes(pill ? "status-pill" : "status", TONES.fetch(tone))
    end
  end
end
