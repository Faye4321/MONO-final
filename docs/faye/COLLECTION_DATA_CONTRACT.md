# Faye — personal collection lifecycle (revised)

## Exact user flow

1. Onboarding step 1, "What do you collect?", contains the four original choices plus a **Custom collection** tile. The custom tile creates a user-named collection; Continue passes it as the destination for the first uploaded object.
2. Later, the center Create tab's photo-upload flow offers a destination picker and **Create a custom collection**. Photo shape is named separately, so the original four crop formats are not mistaken for the available collections.
3. There is **no automatic setup/cleanup modal at onboarding completion**.
4. Accounts registered inside this app version are marked eligible for a first-time cleanup offer. On the Collection page they can **Remove all default examples** or **Keep examples / dismiss**. Either decision is recorded per account; the offer does not return on another device. If no decision is made, the card remains on that account's Collection page until they decide.
5. Old accounts, including accounts made through the Firebase console, are not retroactively enrolled. To check the signup-only offer, register a new test account in the app, not in the Firebase console.
6. Removing examples deletes only known bundled example objects. Personal uploads are retained, as are the default collection categories. All empty collection cards and empty shelf details use the same empty wooden display shelf. Nonempty shelves retain the established layouts.
7. Long-press a collection card, or use the detail menu, to delete that collection. Default and custom collections behave identically: the category/card disappears from the main Collection list, its objects/photos stay in Unfiled, and Recently deleted can restore it.

## Cloud data and compatibility

```
users/{uid}/collections/{UUID}       payload: JSON PersonalCollection; updatedAt
users/{uid}/settings/onboarding     sampleOfferEligible; sampleChoiceMade; removedExamples; updatedAt
users/{uid}/items/{UUID}            existing payload gains optional collectionID
```

`PersonalCollection` has stable `id`, `name`, `layout`, optional `deletedAt`. The four defaults use deterministic IDs; deletion/restoration persists an account-owned override. Deleting a collection never calls `deleteItem` or removes a moment/image. Restoring the same ID reattaches its old members automatically, except objects explicitly moved elsewhere. There is no automatic expiry/hard-delete.

`CollectibleItem.collectionID` is optional for old archives. Missing values map the object format to its legacy default shelf. Explicit Unfiled uses the reserved UUID ending `FFFFFFFFFFFF`. The object's original ID, content, image and category are retained. Object format/crop shape and user-named shelf membership are separate concepts.

All new paths live under `users/{uid}` and use the existing owner-only rules. No new Firebase/Supabase settings or rule updates are needed. This change is separate from shared collection memberships.

## Interfaces

- `activeCollections`, `deletedCollections`, `catalogReady`, `catalogError`, `catalogSyncing`
- `createPersonalCollection(name:layout:) throws -> PersonalCollection`
- `deletePersonalCollection(_:)`, `restorePersonalCollection(_:)`
- `personalCollection(id:)`, `items(in:)`, `unfiledItems`, `resolvedCollectionID(for:)`, `moveItem(_:to:)`
- `onboardingPreferredCollectionID` carries the first-object destination; it is cleared after that save/account switch.
- `requestDefaultCleanupOfferForNewAccount()` is invoked only after app registration succeeds. Its pending registration marker is cached per UID and retried.
- `defaultCleanupOffered` requires a loaded catalog, signup eligibility and no completed decision.
- `completeSampleChoice(remove:)` uses a transaction to read the eligibility/decision and current sample records, then atomically records the choice and any sample tombstones. Already-deleted or user-created records are skipped; concurrent decisions do not perform removal twice.
- `retryCloudSync()` retries durable per-account catalog edits too.

Cloud collection edits are per record, not full-catalog replacement. Local caches/outboxes are account-specific. Same-record concurrent changes remain last successful write wins. The existing cache's new eligibility field is optional so older unsent edits survive upgrades.

Default-example removal retains image files and memories. The Collection page offers a session-only Undo banner until dismissed; it restores the removed object payloads. There is no permanently available bulk delete option. Individual collection restoration is persistent and cross-device.

## Team merge notes

Preserve `collectionID` and its CodingKeys/init/encode changes. Modules that mean user-owned shelves should use `activeCollections`, not `CollectionCategory.allCases` (which still means four object formats). Home/Explore is not redesigned; its old deleted-shelf shortcuts show a notice rather than resurrecting shelves. Profile layout/avatar/Sign Out placement are unchanged.
