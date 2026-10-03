# Shared UI components

Cragmont uses Rails renderable objects (`render_in`) with HAML templates. No new front-end runtime or component gem is required. Public and admin views use the same primitives; domain partials, such as trip cards and participant tables, compose them.

Open `/ui/components` locally for the component catalog. Its route is absent in production.

## Ownership

- `app/components/ui/`: component contracts, allowed variants, and shared classes.
- `app/views/ui/`: canonical HTML, rendered through ordinary Rails helpers for escaping and form behavior.
- `app/helpers/ui_helper.rb`: concise HAML entry points.
- `app/assets/stylesheets/ui/tokens.css`: shared colors and radius.
- `ui/structure.css`: panel, action-group, and stat layout defaults.
- `ui/components.css`: shared appearance, button states, and badge variants.
- `application.css` and `editorial.css`: page composition and responsive arrangements.

Styles load in this order: tokens, structure, application, components, editorial. Structural defaults precede existing page layout rules; component appearance replaces the former editorial overrides. Keep this order until a separately verified CSS migration removes the remaining page-specific dependencies. Do not add page-specific badge sizes or recreate component base styles in those files.

## HAML examples

```haml
= ui_panel(class: "trip-overview", aria: {label: "Trip overview"}) do
  %h2 Yosemite
  = trip_type_badge(trip)
  = ui_badge "Almost full", tone: :warning
  = ui_stats do
    = ui_stat(label: "Participants", value: 3)
    = ui_stat(label: "Open spaces", value: 1, tone: :warning)
  = ui_actions do
    = ui_link "Read report", trip_report_path(report), variant: :secondary
    = ui_button "Contact", type: :button, data: {action: "modal#open"}

= form_with model: trip do |form|
  = required_label form, :name
  = form.text_field :name, required: true
  = ui_actions(kind: :form) do
    = ui_submit form, "Save trip"
    = ui_link "Cancel", trips_path, variant: :secondary

= ui_button_to "Remove", trip_path(trip), method: :delete,
  variant: :danger, form: {data: {turbo_confirm: "Remove this trip?"}}
```

| Component | Supported options |
| --- | --- |
| `ui_badge` | `tone:` neutral, success, warning, danger, draft, archived, open, replied, resolved, day_trip, gym_outing, external_class; `pill:` for existing status-pill layout |
| Buttons | `variant:` primary, secondary, outline, danger, danger_secondary |
| `ui_panel` | `tag:` section (default), article, aside, div |
| `ui_actions` | `kind:` inline (default), form, table; `tag:` div (default), td, section |
| `ui_stats` | Container for stat cells, including existing richer parking/minor breakdowns |
| `ui_stat` | `label:`, `value:`, optional `tone:` success, warning, danger |
| `ui_brand` | URL defaults to root; same brand markup in public and admin navigation |

Use `trip_type_badge` for trip types; it selects the semantic class on the shared badge. Existing domain helpers may also provide semantic classes. A custom `class:` is for composition or an existing domain variant, never a second badge/button implementation.

Use `ui_link` for navigation, `ui_button` for native button interactions, `ui_button_to` for Rails action forms, `ui_submit` with a form builder, and `ui_submit_tag` in tag-based forms. Set `type: :button` for modal open/close controls. `ui_public_link` delegates to the existing external-link privacy helper; it must remain in use where anonymous visitors cannot see member-only destinations.

HTML options pass through unchanged, including IDs, `data`, ARIA, disabled state, names/values, HTTP methods, nested params, and `button_to` form options. Content blocks support nested accessible labels. Panels and action groups add no wrapper beyond their original element. Empty containers retain HAML's whitespace so existing `:empty` rules do not change behavior.

Navigation menu controls and inline text actions can retain their specialized unskinned markup. Dialog behavior, form fields, accessible table structures, permissions, and business rules remain in their existing domain partials/controllers. This refactor does not replace them with generic widgets.

## Verification

Component tests cover escaping, nested content, variants, ARIA/data hooks, form submission names, HTTP methods, params, and disabled states. The catalog browser test covers shared badge dimensions, overflow, form submission, and navigation at 390, 760, and 1440 pixels. Existing controller and browser tests exercise the migrated flows.

The opt-in parity harness captures 33 public/member/admin pages at all three widths (99 full-page screenshots), with fixed time and fixtures. It also records exact text, geometry, and computed styles for headings and shared components. It includes Trips, Past Trips, all trip types, reports and editor, auth, profile, club pages, and admin trip/participant/transaction/readiness screens.

```sh
UI_PARITY_OUTPUT=tmp/ui-parity/after rbenv exec ruby bin/rails test test/system/ui_component_parity_test.rb
rbenv exec ruby script/verify_ui_parity.rb tmp/ui-parity/before tmp/ui-parity/after
```

For a new baseline, copy the same capture test into an isolated checkout of the deployed revision and run it there with `UI_PARITY_OUTPUT` set to the absolute baseline directory. Use the same Chrome version and machine. Run baseline and candidate sequentially: Rails tests share the test database. Never point this harness at production data.

The comparison requires exact component measurements and image dimensions. Pixel comparison tolerates channel differences up to 2, with at most 0.1% of pixels exceeding that and a maximum channel deviation of 16, to allow minor browser rasterization noise. It writes `comparison.json` and difference images. Investigate failures rather than updating the baseline to the candidate.

The initial refactor baseline is production revision `b7bfa3ad1a40fc2b4fc25b87de562bbd466d3a1a` (Heroku v83). This verifies the current deployed code using deterministic local fixtures; it does not copy private production records.

Initial verification: **99/99 captures passed**, with exact text/layout/style measurements in every capture. Of those, 95 had no pixels differing by more than 2 per channel; the maximum changed-pixel proportion in the remaining four was 0.0087%, with maximum channel deviation 12. Images are decoded and scrolled into view before capture to avoid Chrome's deferred photo rasterization. Screenshots and machine-readable results are retained locally in `tmp/ui-parity/`.
