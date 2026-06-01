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

  def visible_environment_name
    return unless Rails.env.development? || Rails.env.staging?

    Rails.env.to_s.titleize
  end

  def show_letter_opener_link?
    Rails.env.development?
  end

  def letter_opener_label
    count = letter_opener_message_count

    count.nil? ? "Letter Opener" : "Letter Opener (#{count})"
  end

  def letter_opener_message_count
    return unless show_letter_opener_link?

    letters_location = letter_opener_letters_location
    return 0 unless letters_location.directory?

    Dir.children(letters_location).count do |entry|
      letters_location.join(entry).directory?
    end
  rescue SystemCallError
    nil
  end

  def letter_opener_letters_location
    if defined?(LetterOpenerWeb) && LetterOpenerWeb.respond_to?(:config)
      LetterOpenerWeb.config.letters_location
    else
      Rails.root.join("tmp", "letter_opener")
    end
  end
end
