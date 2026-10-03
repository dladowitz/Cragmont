module Ui
  class ButtonComponent < BaseComponent
    TEMPLATE = "ui/button"
    VARIANTS = { primary: nil, secondary: "secondary", outline: "outline", danger: "danger", danger_secondary: "danger secondary" }.freeze
    KINDS = %i[link public_link button action submit submit_tag].freeze
    attr_reader :kind, :url, :form

    def initialize(text: nil, kind: :button, variant: :primary, url: nil, form_builder: nil, **attributes)
      super(text: text, **attributes)
      @kind = option!(kind, KINDS, :button_kind)
      @url, @form = url, form_builder
      option!(variant, VARIANTS.keys, :button_variant)
      raise ArgumentError, "Submit buttons require a form builder" if kind == :submit && form_builder.nil?
      @attributes[:name] = nil if kind == :button && !@attributes.key?(:name)
      add_classes("button", VARIANTS.fetch(variant))
    end
  end
end
