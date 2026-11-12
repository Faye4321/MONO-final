# MONO — Final

SwiftUI collection app for IDSN 533. This project is in development; App Store publication is not required.

## Run the submitted project

1. Clone/download the whole repository, not just the `.xcodeproj` file.
2. Open `MonArchive.xcodeproj` in Xcode. Select the shared **MonArchive** scheme and an iPhone simulator.
3. Allow Swift Package Manager to restore dependencies. `Package.resolved` is committed (Firebase 13.1.1, Supabase Swift 2.55.6). The checked-in bundle identifier is `com.yufei.monarchive5333`.
4. Run. Create an account or log in with an existing **MONO app** account. Each reviewer can create their own account; no shared password is required.
5. On a physical iPhone, select your own signing Team in Signing & Capabilities. The simulator does not require a paid Apple Developer membership. Do not change the bundle identifier unless you also register a matching Firebase iOS app and replace its configuration file.

Validated using Xcode 27.2 with an iOS Simulator build; deployment target is iOS 17. Package requirements may require a recent Xcode version. If a dependency requires a newer toolchain, update Xcode rather than silently changing the locked versions.

The Firebase client plist and Supabase publishable key are included so teammates can use the same development backend. These are client configuration, **not server/admin credentials**. Access is controlled by deployed Firestore and Storage rules. Do not commit account passwords, Firebase service-account JSON, Supabase secret/service-role keys, or Apple signing keys.

## Cloud architecture

- **Firebase Authentication:** email/password identity. Signing into the same account recovers the same archive.
- **Firestore:** per-account items and moments, deletion tombstones, shared collection records, memberships and invitations.
- **Supabase Storage:** private original object/memory photos under `<Firebase UID>/<image filename>`.
- **Local cache/outbox:** account-specific files; failed writes remain on the device and can retry on foreground or via Profile → Cloud & shared collections → Retry sync.
- **Shared images:** bounded JPEG previews (at most 180 KB each) accompany independent shared item snapshots in Firestore. Friends never receive access to the owner's private Supabase image folder. The original-resolution image remains private. This small-demo approach consumes Firestore's document/storage/read quotas; it is not designed for a large image feed.

### Data paths and interfaces

```
users/{uid}/items/{itemUUID}       # deleted + JSON payload + updatedAt
users/{uid}/moments/{momentUUID}   # deleted + JSON payload + updatedAt
sharedCollections/{collectionUUID}
sharedCollections/{collectionUUID}/items/{itemUUID}
invites/{64-character random token}
```

Existing module methods (`addItem`, `updateItem`, `deleteItem`, `addMoment`, `updateMoment`, `deleteMoment`, `importItems`, `partWith`, `restore`) now persist account data to the cloud. Existing views do not need to write Firestore directly. `cloudStatus`, `cloudError`, `cloudReady`, and `retryCloudSync()` expose sync state.

`SocialStore` provides `createSharedCollection`, `addItem(_:to:)`, `invitation(for:)`, `joinCollection(invitation:)`, and `cloudItems`. The shared collection detail reads `cloudItems`, not another user's local archive.

## Backend setup — project owner only

Teammates using the existing backend do not need to repeat this configuration. Uploading to GitHub does not deploy backend permissions.

1. In Firebase project **mono-6d8ad**, enable Authentication → Email/Password and create the default Firestore database.
2. **Required for sharing:** replace Firestore → Rules with the complete contents of [`cloud/firebase/firestore.rules`](cloud/firebase/firestore.rules), then Publish. The earlier personal-only rule cannot support invitations/shared collections. Alternatively use Firebase CLI: `firebase deploy --only firestore:rules --project mono-6d8ad`.
3. In Supabase project **etkucvnppsvgpqytlhwe**, keep Firebase Third-party Auth enabled with Firebase project ID **mono-6d8ad**.
4. Run [`cloud/supabase/storage.sql`](cloud/supabase/storage.sql) in Supabase SQL Editor. It creates/updates the PRIVATE `collectible-images` bucket, applies a 5 MB image limit, and installs owner-only policies. The script is safe to re-run. Remove any older broad/public policies if you added any separately: permissive policies are additive.
5. No custom Firebase `role` claim is necessary for this policy design: a verified Firebase JWT's issuer, audience and subject are explicitly checked even under the `anon` database role. An unauthenticated publishable key cannot pass these checks. Do not replace the policy with `true` or open public reads.
6. Firebase Storage is not used and does not need Blaze. Supabase Free and Firestore free quotas still apply. Free hosting is not unlimited; Supabase inactive free projects can pause, so check backend availability before the final demo.

For a different team's backend, replace `GoogleService-Info.plist`, the URL and publishable key in `CloudStorage.swift`, Firebase project IDs in the Supabase SQL and smoke-check script, and enable the third-party integration for that project. Keep all three IDs consistent.

## Demonstrate cloud recovery

1. Account A: create an object with a new photo, edit its note, and add a memory/photo. In Profile expand **Cloud & shared collections** and wait for **Up to date**, with no error.
2. Open a separate simulator/device with a fresh installation and log into A. Check the new object, edited note, object photo and memory/photo.
3. Edit the object on device B; wait for device A's live listener to update it.
4. Delete the object and confirm it disappears on both. Deletion markers prevent the bundled demo object from returning after restart. Unreferenced original photos are removed after their associated metadata writes complete.
5. Sign out and log into a different account B. A's personal objects must not appear. Bundled demo objects are the same for all users and are not evidence of a leak.
6. If upgrading an existing local archive, use Profile → Cloud & shared collections → **Import collections from before this update**. This explicitly assigns old, unowned user-created objects/memories to the signed-in account; the original local archive is left intact. Do this only on the device containing the old data. Edits/deletions to demo objects in the old unowned archive are not imported.

## Demonstrate sharing

1. Account A: Profile → Shared Collections → `+`. Choose a name and permissions, and optionally personal objects. Create, then wait until the collection appears. Errors are shown in the Cloud panel.
2. Open the shared collection → `…` → **Share Invitation**. Copy/send the `mono://collection?invite=...` link. Anyone possessing the invitation can join while signed in, so treat it as an invitation secret.
3. Account B: log in to this app and open the link, or paste the link/code into Profile → Cloud & shared collections → **Join collection**. Pasting is the reliable fallback when a messaging app does not open custom schemes.
4. B should see the shared text and image preview without owning the original personal object. Under **Everyone can add**, B can contribute an object and A sees the shared snapshot. Under **Only I can add**, B cannot add objects; backend rules enforce this too.

Shared links open the installed iOS app. A browser preview, web hosting, App Store routing, and universal links are not included. Shared items are independent snapshots: subsequent edits/deletions to a personal original do not change the shared copy. Membership removal/revocation UI, handle search, and cloud chat are not implemented in this delivery. Existing chat remains session-local. Do not present those features as cloud-synced in the final demo.

## Scope and conflict behavior

Cloud work covers Collection/Create objects, moments and their photos, plus basic shared collection creation, invitation, membership and shared snapshots. Profile text, collecting preferences, custom categories, Lab designs, friend discovery and other midterm UI data are not migrated to cloud in this delivery. Profile fields/preferences still use existing local settings; they should not be used to demonstrate per-account cloud profiles.

Each item/memory is a separate record. Edits to different records do not overwrite an entire archive. Simultaneous edits of the same record use last successful write wins; this is not a conflict-resolution system. Offline changes are durable locally, but must finish uploading before a new device can recover them. Firestore first-load errors appear in a loading overlay; a cache allows later offline use. Automatically deleting the app also deletes its unsent local changes.

## Validation

- Simulator compilation and service checks are recorded in [`docs/validation.md`](docs/validation.md).
- `python3 scripts/check_cloud.py --live` creates two temporary test accounts, tests Firestore and Supabase recovery/isolation using the public client configuration, then removes test data/accounts. It does not test SwiftUI or deploy rules.
- [`docs/final-checklist.md`](docs/final-checklist.md) is the manual device/reviewer checklist, including shared invitation permissions.

## GitHub submission

Commit the project folder contents, including `MonArchive/`, `MonArchive.xcodeproj/`, `cloud/`, `scripts/`, `docs/`, `.gitignore`, `firebase.json`, and this README. Do not upload only a ZIP or only `.xcodeproj`. Use GitHub Desktop to commit and push all changes. Check that `Package.resolved` and the shared scheme are visible online. No `DerivedData`, `SourcePackages`, user state or admin credentials are needed in the repository.
