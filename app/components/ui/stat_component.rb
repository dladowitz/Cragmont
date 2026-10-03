module Ui
  class StatComponent < BaseComponent
    TEMPLATE = "ui/stat"
    attr_reader :label, :value

    def initialize(label:, value:, tone: nil, **attributes)
      super(**attributes)
      @label, @value = label, value
      if tone
        option!(tone, %i[success warning danger], :stat_tone)
        add_classes("availability-stat", "#{tone}-stat")
      end
    end
  end
end
