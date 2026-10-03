module Ui
  class ActionGroupComponent < BaseComponent
    TEMPLATE = "ui/container"
    KINDS = { inline: "actions", form: "form-actions", table: "table-actions" }.freeze

    def initialize(kind: :inline, tag: :div, **attributes)
      super(**attributes)
      @tag_name = option!(tag, %i[div td section], :action_group_tag)
      option!(kind, KINDS.keys, :action_group_kind)
      add_classes(KINDS.fetch(kind))
    end
  end
end
