module Ui
  class PanelComponent < BaseComponent
    TEMPLATE = "ui/container"

    def initialize(tag: :section, **attributes)
      super(**attributes)
      @tag_name = option!(tag, %i[section article aside div], :panel_tag)
      add_classes("panel")
    end
  end
end
