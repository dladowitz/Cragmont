module Ui
  class StatsComponent < BaseComponent
    TEMPLATE = "ui/container"

    def initialize(**attributes)
      super
      @tag_name = :div
      add_classes("stats")
    end
  end
end
