require "test_helper"

class Ui::ComponentsTest < ActionView::TestCase
  include UiHelper

  test "badges escape text and preserve semantics and hooks" do
    html = Nokogiri::HTML.fragment(ui_badge("<script>alert(1)</script>", tone: :warning, id: "capacity", data: { readiness_count_key: "overall" }))
    assert_nil html.at_css("script")
    assert_equal "<script>alert(1)</script>", html.at_css("span").text
    assert_equal "overall", html.at_css("#capacity.warning-status")["data-readiness-count-key"]
    assert_includes ui_badge("Open", tone: :open, pill: true), "status-pill open-status"
  end

  test "links preserve nested accessible content and routing attributes" do
    html = Nokogiri::HTML.fragment(ui_link("/trips", variant: :secondary, aria: { label: "View trips" }, data: { turbo: false }) { tag.strong("Trips") })
    link = html.at_css("a.button.secondary")
    assert_equal "/trips", link["href"]
    assert_equal "View trips", link["aria-label"]
    assert_equal "false", link["data-turbo"]
    assert_equal "Trips", link.at_css("strong").text
  end

  test "action buttons preserve Rails methods params and form options" do
    html = Nokogiri::HTML.fragment(ui_button_to("Remove", "/trips/1", method: :delete, variant: :danger_secondary,
      params: { payment: { issue_refund: "0" } }, form: { class: "confirmation", data: { turbo: false } }))
    form = html.at_css("form.confirmation")
    assert_equal "/trips/1", form["action"]
    assert_equal "false", form["data-turbo"]
    assert_equal "delete", form.at_css("input[name='_method']")["value"]
    assert_equal "0", form.at_css("input[name='payment[issue_refund]']")["value"]
    assert_equal "Remove", form.at_css("button.button.danger.secondary").text
  end

  test "buttons preserve disabled state and explicit submission intent" do
    html = Nokogiri::HTML.fragment(ui_button("Publish", type: :submit, name: "intent", value: "publish", disabled: true, data: { action: "report#publish" }))
    button = html.at_css("button[type='submit'][name='intent'][value='publish']")
    assert button.key?("disabled")
    assert_equal "report#publish", button["data-action"]
    assert_nil Nokogiri::HTML.fragment(ui_button("Close", type: :button)).at_css("button")["name"]
  end

  test "submit components retain form builder names and data attributes" do
    builder = ActionView::Helpers::FormBuilder.new(:trip, Trip.new, self, {})
    html = Nokogiri::HTML.fragment(ui_submit(builder, "Save", variant: :secondary, data: { report_editor_target: "saveButton" }))
    submit = html.at_css("input[type='submit'].button.secondary")
    assert_equal "Save", submit["value"]
    assert_equal "saveButton", submit["data-report-editor-target"]
  end

  test "panels action groups and stats preserve direct child structure" do
    html = Nokogiri::HTML.fragment(ui_panel(tag: :article, id: "overview", class: "trip-overview") do
      ui_stats { ui_stat(label: "Open spaces", value: 3, tone: :warning) }
    end)
    assert_equal "3", html.at_css("article#overview.panel.trip-overview > .stats > .availability-stat.warning-stat > strong").text
    row = Nokogiri::HTML.fragment(ui_actions(kind: :table, tag: :td, role: "cell", data: { label: "Actions" }) { ui_link("Edit", "/edit") })
    assert_equal "Edit", row.at_css("td.table-actions > a.button").text
    assert_equal "Actions", row.at_css("td")["data-label"]
    assert_includes ui_actions(kind: :table) { "" }, ">\n</div>"
  end

  test "unsupported component variants fail clearly" do
    assert_raises(ArgumentError) { Ui::BadgeComponent.new(tone: :huge) }
    assert_raises(ArgumentError) { Ui::ButtonComponent.new(variant: :huge) }
    assert_raises(ArgumentError) { Ui::ButtonComponent.new(kind: :submit) }
    assert_raises(ArgumentError) { Ui::PanelComponent.new(tag: :script) }
    assert_raises(ArgumentError) { Ui::ActionGroupComponent.new(kind: :unknown) }
  end
end
