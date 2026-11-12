# Collection lifecycle acceptance

## Checks completed in the delivery copy
- Full iOS Simulator compilation: PASS (Xcode 27.2).
- Data compatibility checks: PASS for all 40 old-format bundled objects, optional custom membership round-trip, preserved artwork/type, stable default shelf IDs, and recoverable soft-deletion identity.
- No live backend writes or modifications to the working GitHub repository were used for these new checks.

## Latest revision checks
- Old catalog caches keep their unsent edits when the optional signup-eligibility field is absent: PASS.
- Actual cleanup-offer predicate: old accounts hidden; new eligible accounts shown; completed decision hidden; unloaded account hidden: PASS.

## Manual checks still required (both devices need this version)
1. Create a custom collection with a non-default name. Add an object into it. Wait for catalog and object synchronization without errors; verify the collection and object on a second device using the same account.
2. Delete each kind of default shelf and a custom shelf. Each should leave the visible Collection list after confirmation; the object count must not drop and photos/memories must remain.
3. Open Unfiled, verify retained objects/photos, then restore the deleted shelf through Recently deleted. The original member objects return to that shelf.
4. Move an unfiled object into another active shelf using Edit Object; restore its old shelf. The moved object must stay in the newly chosen shelf.
5. Delete all four defaults and all custom shelves; Collection still offers Create a Collection and Unfiled. Creating an object must not require a deleted shelf.
6. Register a fresh test account inside this app version, finish onboarding and verify the optional cleanup card appears on Collection (no automatic modal). Choose Keep. Relaunch and log into the same account on another device; the choice must not appear again.
7. Register another fresh account in the app. Choose Custom on onboarding step 1 and upload the first object into it. On Collection, before making the cleanup decision, verify the custom collection contains that upload. Then select Remove on Collection, confirm, and verify the personal upload remains while bundled examples disappear. The four default shelves should remain empty/with personal contents. Undo restores the removed examples without duplicating personal uploads.
8. Dismiss Undo and restart. The choice must not reappear; there must be no persistent bulk-delete control. Shelves remain individually recoverable.
9. Make shelf changes after loading the account, go offline, restart, then reconnect and Retry sync. Check durable local edits and eventual recovery on another device. Same-shelf concurrent edits are last-write-wins.
10. Change accounts; neither custom shelf names nor their deleted state should leak across accounts.

Cloud transactions, SwiftUI flows, two-device behavior and offline retries have not been manually exercised by this delivery. Do not treat compilation/data-format checks as proof that every scenario above has passed.

11. All empty default/custom cards and empty detail views use one empty wooden display shelf. Delete all four categories individually: their cards must disappear and the header must show the actual count (zero), while retained objects remain accessible in Unfiled.
12. Log into an old account: no signup-only cleanup offer should be injected. New-account registration is tested through the App, not the Firebase console.

## Revised delivery build
- Full generic iOS Simulator build after relocating cleanup to Collection and inserting Custom into onboarding step 1: PASS (Xcode 27.2).
- Existing tutorial-arrow availability and calendar reduce-motion capture warnings were repaired for the iOS 17 target; the original project was not modified.
- The signup-only eligibility/cache tests passed. No live cloud data was changed for this revision.
- Visual/device onboarding, first upload, empty states and two-device behavior still require the manual checks above.
