module UiHelper
  def ui_badge(text = nil, **options, &block)
    render Ui::BadgeComponent.new(text: text, **options), &block
  end

  def ui_link(text = nil, url = nil, **options, &block)
    text, url = nil, text if block && url.nil?
    render Ui::ButtonComponent.new(text: text, url: url, kind: :link, **options), &block
  end

  def ui_public_link(text, url, **options)
    render Ui::ButtonComponent.new(text: text, url: url, kind: :public_link, **options)
  end

  def ui_button(text = nil, **options, &block)
    render Ui::ButtonComponent.new(text: text, kind: :button, **options), &block
  end

  def ui_button_to(text = nil, url = nil, **options, &block)
    text, url = nil, text if block && url.nil?
    render Ui::ButtonComponent.new(text: text, url: url, kind: :action, **options), &block
  end

  def ui_submit(form, text = nil, **options)
    render Ui::ButtonComponent.new(text: text, kind: :submit, form_builder: form, **options)
  end

  def ui_submit_tag(text = nil, **options)
    render Ui::ButtonComponent.new(text: text, kind: :submit_tag, **options)
  end

  def ui_panel(**options, &block)
    render Ui::PanelComponent.new(**options), &block
  end

  def ui_actions(**options, &block)
    render Ui::ActionGroupComponent.new(**options), &block
  end

  def ui_stats(**options, &block)
    render Ui::StatsComponent.new(**options), &block
  end

  def ui_stat(**options)
    render Ui::StatComponent.new(**options)
  end

  def ui_brand(url = root_path, **options)
    render Ui::BrandComponent.new(url: url, **options)
  end
end
