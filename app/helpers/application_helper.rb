module ApplicationHelper
  def required_marker
    safe_join([
      tag.span("*", class: "required-marker", aria: { hidden: "true" }),
      tag.span("required", class: "visually-hidden")
    ], " ")
  end

  def required_label(form, method, text = nil, options = {})
    form.label(method, nil, options) do
      safe_join([ text || method.to_s.humanize, required_marker ], " ")
    end
  end

  def required_label_tag(name, text = nil, options = {})
    label_tag(name, nil, options) do
      safe_join([ text || name.to_s.humanize, required_marker ], " ")
    end
  end
end
