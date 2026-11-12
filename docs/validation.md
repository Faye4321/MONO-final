# Validation — 2026-11-11

## Completed

- Full Xcode 27.2 simulator build (`generic/platform=iOS Simulator`, signing disabled) succeeded after the cloud integration.
- Final ZIP extracted into a different folder and rebuilt with the shared scheme: PASS. Cached package dependencies were reused; this verifies project-relative paths, not a cold online package download.
- Project and Info plist syntax checked using `plutil`.
- Live service smoke check used **two temporary Firebase accounts**, then deleted both accounts and the test data:
  - Firestore write into the signed-in user's path: PASS.
  - Other account reading the private document: denied, PASS.
  - Fresh email/password login reading the saved document: PASS.
  - Supabase private image upload using Firebase JWT: PASS.
  - Fresh login downloading byte-identical image: PASS.
  - Other account and unsigned client reading private image: denied, PASS.
  - Temporary objects, document and accounts cleaned up: PASS.
- No service/admin keys were used; the smoke check reads only the public client configuration.

## Requires project-owner / device verification

The app's new shared collection rules are supplied in `cloud/firebase/firestore.rules`. They have **not been deployed by this delivery**. The project owner must publish the complete rules before sharing works.

Sharing, offline restart/recovery, SwiftUI flows, image appearance, legacy import and two-device live synchronization still require the manual checklist in `final-checklist.md`. A successful build and REST service smoke check do not substitute for those UI/device tests. No claim is made that these manual scenarios have passed.

## Known scope

Shared copies include compressed image previews, not access to private originals. Chat, profile/preferences and Lab designs are still local/session-only. Same-record concurrent edits use last successful write wins. Free service quotas and Supabase project availability apply.

See README for how to repeat the checks and run from a GitHub checkout.
