# Camping member priority

Admin → Settings controls the **Member-only signup period (days)**. The default is 15; 0 disables it. Only super admins can edit this setting, using the existing Settings permission.

The window starts when a camping trip is first published, not while it is a draft or relative to its departure date. Each trip stores its first publication and non-member opening timestamps. The opening preserves the club's California wall-clock time across daylight-saving changes. At the opening instant, non-members can register without a scheduled job.

Changes to the setting affect future first publications. Editing, unpublishing, or republishing a trip does not restart or extend its announced window. The migration uses `created_at` as the legacy publication marker (the actual historical publication time was not recorded) and leaves already-published and archived trips unrestricted; existing drafts receive the configured window when first published. Day trips, gym outings, and external classes are unaffected.

Trips remain publicly visible. The list shows a shared “Members first” badge and the camping detail explains the exact opening date, time, and time zone, with membership information and a login link. During priority, the existing `User#member?` flag controls public registration. Non-members cannot create a signup, join a waitlist, or claim a waitlist spot, even by posting directly or submitting an old form. Existing confirmed/pending participants retain details/payment/cancellation access. Waitlisted participants can still withdraw.

This is priority for the registering member's account. Existing guest/minor allowances remain unchanged. Authorized admins retain their existing ability to add or manage participants; no new admin override permission is introduced. The climbing partner board remains separate from trip registration.

Validation covers the default/custom/disabled setting, invalid input and authorization, draft versus publication timing, republishing, legacy trips, daylight saving, exact expiry, member/non-member submissions and waitlist paths, existing participants, and responsive settings/notice layouts at 360, 760, and 1440px.
