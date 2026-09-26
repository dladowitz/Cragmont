### Cragmont Climbing Club

For new pages and UI changes, see the [design language and UX decisions](docs/design-language.md).



### Running Development
You need to setup a Stripe Webhook

In the terminal
`> stripe listen --forward-to localhost:3000/stripe/webhooks`
`Your webhook signing secret is whsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

Update the .env.development file
`STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`


Start Rails Server in the terminal
`> rails s`

### Calendar subscriptions

The Trips page offers a subscription to `/trips/calendar.ics`; paste its HTTPS URL into Google Calendar's "From URL" or another calendar app's subscription settings. Calendar apps choose their own refresh interval. Each trip also offers a one-time `.ics` download.

The feed includes published and archived trips, excludes drafts and deleted trips, and omits descriptions and member links. Camping trips cover their full date range. Single-day events with meeting times use America/Los_Angeles (including daylight saving time); events without times are all-day. Trip forms currently have no per-event time zone.
