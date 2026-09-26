# Cragmont design language

Use this guide when adding or changing a page. It records the choices already expressed in the site, not a second set of CSS tokens. The working sources are [`application.css`](../app/assets/stylesheets/application.css), [`editorial.css`](../app/assets/stylesheets/editorial.css), the [public header](../app/views/shared/_public_header.html.haml), and the [admin header](../app/views/admin/shared/_header.html.haml). Inspect those before adding a new pattern.

## What the site should feel like

Cragmont is a real climbing club, not a booking marketplace. Pages should feel outdoorsy, welcoming, trustworthy, and useful. Let climbing photography and specific destinations supply the personality; keep the interface restrained enough that trip details, safety information, and next actions remain easy to scan.

- Lead with the answer to a visitor's question. Use a clear page title, a short lead, then the details and one obvious next action.
- Prefer concrete club language over marketing claims. Explain what the club does and what a participant needs to know without implying that Cragmont provides instruction or certifies climbing ability.
- Use climbing language in feedback where it helps, especially successes and recoverable errors. Keep labels, instructions, money, dates, and safety copy literal. Say **participant** for a person on a trip; use **signup** for the registration action or record.
- Keep public pages warm and editorial; keep admin pages compact and task-focused. Do not make a safety warning, payment error, or destructive action playful.

## Visual rules

| Element | Established choice | Why |
| --- | --- | --- |
| Type | One sans-serif family; regular-weight, tight-tracked headings; readable body text | Photography and content do the expressive work. |
| Palette | Warm off-white background, near-white panels, deep green text/actions, muted green-gray metadata | Feels outdoorsy without competing with photos. Use the CSS custom properties; do not copy hex values into a new page. |
| Surfaces | Thin borders, small radius, little or no shadow | Group content without making every section look like a floating card. |
| Width | Shared `public-main`/`panel` rhythm; narrower `club-main` and readable `club-copy` for long prose | Wide for trip browsing, comfortable line lengths for reading. |
| Photography | A relevant climbing image where it adds context; overlay or panel for text; location caption | A photo is not a substitute for a heading or legible copy. |
| Actions | Filled green primary button; outlined secondary; danger style only for destructive actions | The next step should be unmistakable. |
| Badges | Compact text **and** color. Camping/default is green, day trip is blue, external class is amber; operational statuses retain their own semantic colors | The type/status must remain understandable without color. Preserve these distinctions when making pages. |

The current public examples are [home](../app/views/home/index.html.haml), [trips](../app/views/trips/index.html.haml), [membership](../app/views/club/membership.html.haml), and [history](../app/views/club/history.html.haml). Reuse their HAML structure and existing classes before inventing a new component. `editorial.css` carries the newer visual treatment; check `application.css` for the original component and responsive rules before editing either file. Avoid stacking a page-specific override on a shared style unless the page genuinely differs.

## Page patterns and decisions

1. **Navigation is grouped by intent.** The public header has Club (Membership, History, Get Help, About) and Trips (Trips, Past Trips, Join the List). Login and Signup are distinct buttons, not buried in a dropdown. Preserve the same destinations and hierarchy on mobile. The club pages also use the local subnavigation with `aria-current="page"`.
2. **A page has one primary job.** Trip index helps someone find an outing; trip detail helps them decide and act; club pages explain the organization and point toward trips or the email list. Do not give three competing primary CTAs.
3. **Use the right content container.** A photo-led page needs readable contrast over its image and an explicit mobile composition. A text-heavy club page uses an eyebrow, H1, lead, section headings, and restrained panel. Admin pages use the existing header, panels, tables/forms, and direct labels.
4. **Trip metadata stays visible.** Type badge, dates, location, and available space are scan-first information. Distinguish draft/published/archived and trip types in words as well as color. Do not hide a critical fact behind hover, a disclosure, or an image.
5. **Forms are honest.** Mark every required field with the red `*` via `required_label`/`required_label_tag`, pair it with the actual `required` input attribute when applicable, and put useful errors near the form. Group related fields with headings/fieldsets. After a successful action, show what happened and the next step; after failure, preserve entered data where possible.
6. **Links navigate; buttons act.** Keep external links identifiable and safe. Separate joining the email list from creating a site account; they are different actions. Preserve member-only link privacy rather than exposing URLs in public copy.

## Accessibility and responsive acceptance

Before calling a new page finished, check it at approximately **360px, 760px, and desktop width**, plus keyboard navigation. The existing design uses 44px-or-larger navigation targets, a visible focus ring, mobile menus, and horizontally scrollable dense admin tables. Confirm:

- No horizontal page overflow, clipped controls, unreadable photo text, or CTA hidden below an oversized hero on narrow screens.
- One H1, meaningful heading order, explicit form labels, useful image alt text (or empty alt for decorative images), and captions for meaningful climbing photography.
- Menus, disclosures, forms, and dialogs work with keyboard and have visible focus; meaning does not depend on color alone.
- Loading, empty, validation, success, and permission states make sense. Realistic long names, missing optional data, and zero available spaces do not break the layout.
- Trip/privacy/safety language remains accurate for signed-out and signed-in visitors. Do not use a static screenshot as proof of an interactive flow.

## First-pass workflow for a new page

1. Write its one-sentence job and intended audience (visitor, participant, or admin). Identify the primary CTA and the facts needed before that action.
2. Start from the closest existing HAML page and shared header. Reuse tokens, components, badge helpers, and copy patterns. Add CSS only for a real new layout or state.
3. Put realistic content in every state, including long text and empty data. Review desktop and narrow screens, then keyboard and form errors before declaring the design done.
4. Run relevant tests and the full Rails suite before pushing. A page is ready when the visible result and its behavior both match this guide, not merely when it compiles.
