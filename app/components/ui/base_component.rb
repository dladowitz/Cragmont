module Ui
  # Rails' renderable-object protocol keeps components compatible with HAML,
  # capture, normal escaping, and Rails form/URL helpers without another runtime.
  class BaseComponent
    include ActionView::Helpers::TagHelper

    attr_reader :attributes, :tag_name

    def initialize(text: nil, **attributes)
      @text = text
      @attributes = attributes
    end

    def render_in(view_context, &block)
      content = block ? view_context.capture(&block) : @text
      view_context.render(partial: self.class::TEMPLATE, locals: { component: self, content: content })
    end

    def format
      :html
    end

    private

    def add_classes(*names)
      @attributes[:class] = class_names(*names, @attributes[:class])
    end

    def option!(value, choices, name)
      return value if choices.include?(value)

      raise ArgumentError, "Unknown #{name}: #{value.inspect}; expected #{choices.join(', ')}"
    end
  end
end
