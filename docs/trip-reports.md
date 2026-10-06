# Trip reports

## Editing

Open `/admin/trip_reports`, choose **New trip report**, and select a trip. Existing reports reopen instead of duplicating. Global trip admins can also add historical reports without a trip, or link an imported report to a trip. Assigned coordinators can only manage their own linked trips; finance access alone does not grant report access.

The editor prefills trip metadata. Story, byline, and album are optional individually; publishing requires at least a story, album, or photo. Changes autosave privately. **Publish report / Publish changes** updates the live snapshot and opens the public report; **Hide report** removes the entry until explicitly republished. Draft edits, photo removals, and reordering do not change live content. Conflicting saves return 409 rather than overwriting another editor.

New public trips default to automatic photo-album reports after their final Pacific date (or an outing's actual end time, including overnight outings). Existing trips retain `auto_trip_report: false`: their member-only albums are not retrospectively exposed. The trip form makes the automatic-publication option explicit. No scheduled job or manual archival is required. Removing the album or disabling automatic reports removes a photo-only entry, but does not unpublish an explicitly published report; use Hide report for that.

Google Photos links are not scraped or imported, so changing an album's cover in Google Photos does not change the site. Keep the full photo set in the linked album. To change a report's thumbnail, use **Upload cover photo** in the editor, then publish. The upload goes first in the photo list and replaces the archive thumbnail on the card; the full report keeps the archive image too. Existing archive thumbnails remain local assets. Uploaded photos use the existing Active Storage service, have type/size/pixel limits, and are served through report authorization checks with metadata removed.

## Browser-session API

The machine-readable contract is `/openapi.json`, also discoverable at `/.well-known/openapi.json` and via the HTML `service-desc` link. Use the signed-in person's session and `X-CSRF-Token` from the current admin page. No separate agent credential is needed. Never copy cookies or CSRF values into messages or source files.

| Request | Purpose |
| --- | --- |
| `GET /api/v1/trip_reports?q=...&status=draft` | Scoped list; status also accepts `published` or `hidden` |
| `POST /api/v1/trip_reports` | Create a private draft, with `trip_report: {trip_id, ...fields}` |
| `GET /api/v1/trip_reports/:id` | Read authorized draft and current `lock_version` |
| `PATCH /api/v1/trip_reports/:id` | Save `trip_report: {lock_version, ...fields}` |
| `PATCH /api/v1/trip_reports/:id/publish` | Explicit publication with `{lock_version}` |
| `PATCH /api/v1/trip_reports/:id/hide` | Explicit suppression with `{lock_version}` |
| `POST /api/v1/trip_reports/:id/cover_photo` | Multipart `photo` (one file) and `lock_version`; adds a draft cover photo |

Draft fields: `title`, `start_date`, `end_date`, `location`, `trip_type`, `body` (Markdown), `byline`, `album_url`, `photos` (ordered `{id, caption}` objects for existing attachments). The report list shows one thumbnail per card: the first published photo (the cover), else the original archive image. Full report pages show existing attachments in evenly sized gallery tiles, with no oversized first photo. Reports without images use the site's Fairview Dome landscape as a sample thumbnail. Removing an ID from the draft does not purge a currently published attachment. Requests return the updated version; use it for the next write. On 409, stop and reconcile against a fresh GET; do not blindly retry. Invalid content/uploads return 422, insufficient permission 403, and missing authentication 401. Automatic entries may have `id: null`; create their trip-linked draft before editing. GET requests never create records.

## Migration and staging runbook

1. Run focused report tests, `bin/rails test`, and `bin/rails test:system` using `rbenv exec ruby` before pushing.
2. Confirm target is **cragmont-staging**, not production. Deploy the current branch via Heroku Git. The existing release phase runs `db:migrate`.
3. `20260927010000` creates the snapshot-based report table and unique trip/legacy keys. It backfills existing trips with automatic publication **off**, then changes the default to **on** for future trips. Do not bulk-enable existing trips without reviewing album privacy.
4. `20260927010100` imports all 22 archive reports from `db/data/legacy_trip_reports.json`. Text, attribution, album links, and asset filenames are retained. The import is repeatable (`LegacyTripReportImport.call`) and never overwrites edits. Do not run all seeds against staging to import reports.
5. Verify release status, `/trip-reports`, a legacy report/image, the API contract, signed-out admin denial, and the report editor with an existing authorized account. Verify Active Storage is the existing Bucketeer service, not ephemeral dyno disk.

Rollback: the legacy import is intentionally irreversible because reports may have been edited or linked. Roll back application code if necessary while retaining the additive schema and data; do not drop reports or purge attachments. Existing member-only links remain private regardless of code rollback. Never use Heroku commands that print config variables or full release configuration in transcripts.
