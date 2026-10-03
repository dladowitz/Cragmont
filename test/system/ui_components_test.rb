require "application_system_test_case"

class UiComponentsTest < ApplicationSystemTestCase
  test "catalog keeps shared controls usable at phone tablet and desktop widths" do
    [ 390, 760, 1440 ].each do |width|
      page.current_window.resize_to(width, 1000)
      visit ui_components_path
      assert_selector "h1", text: "UI components"
      assert_selector ".status", count: Ui::BadgeComponent::TONES.size
      assert_selector "button[disabled]", count: Ui::ButtonComponent::VARIANTS.size
      assert_selector ".stats > div", count: 4
      assert_selector "label[for='example'] .required-marker"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("innerWidth")
      dimensions = page.evaluate_script("[...document.querySelectorAll('.status')].map(n => [getComputedStyle(n).fontSize, n.getBoundingClientRect().height])")
      assert_equal 1, dimensions.uniq.size, "Badge sizing should come from the shared component"
      fill_in "Example label", with: "On belay"
      click_button "Preview", exact: true
      assert_current_path(%r{/ui/components\?.*example=On(?:\+|%20)belay})
      click_link "Trips", exact: true
      assert_current_path trips_path
    end
  end
end
