# Final acceptance checklist

## Preparation
- [ ] Project owner publishes `cloud/firebase/firestore.rules` (personal-only rules do not support sharing).
- [ ] Owner confirms private Supabase bucket, Firebase third-party integration and `cloud/supabase/storage.sql`.
- [ ] Supabase project is awake before presentation; free-project inactivity can pause the service.
- [ ] Reviewer clones the complete repo into a different folder; package versions restore; shared MonArchive scheme builds.

## Account and persistence (two devices or two independent simulators)
- [ ] Sign up A; password mistakes show errors; sign in A; restart preserves authentication.
- [ ] Create an object with a photo and a memory with a photo. Wait for Up to date and no errors.
- [ ] Sign in A on device B. All text, original object photo and memory photo recover.
- [ ] Edit A's object on B; A receives it without restarting.
- [ ] Delete a custom object and a bundled object; neither returns after relaunch/new-device sign-in.
- [ ] Remove an unreferenced image; metadata sync succeeds before original image cleanup.
- [ ] Go offline after loading: add/edit, restart while offline, then reconnect and tap Retry sync. Verify unsent edits survive and eventually reach the other device.
- [ ] Sign out A and sign in B. A's personal objects/memories do not appear. Each account has separate cache/outbox.
- [ ] Explicit legacy import only assigns existing local user-created objects to the intended account; original unowned archive is preserved.

## Shared collections
- [ ] A creates a collection without selecting a fake/demo friend.
- [ ] Copy invitation. B signs in and pastes it into Profile → Cloud & shared collections → Join collection.
- [ ] B sees the shared text and preview without having that object in B's private archive.
- [ ] A and B both see additions in Everyone can add mode.
- [ ] In Owner only mode, B cannot add (backend rejection must hold even if a UI control is bypassed).
- [ ] A signed-in account without an invitation/member record cannot read shared item documents.
- [ ] Signed-out invitation opening routes to login; link can be pasted again as a fallback.
- [ ] Do not claim browser preview, cloud chat, handle discovery, editable memberships or live personal-to-shared copy updates.

## GitHub handoff
- [ ] Commit source, assets, project, Package.resolved, shared scheme, cloud rules and README.
- [ ] No DerivedData, per-user Xcode state, passwords, service-account JSON, service_role/secret keys or signing files.
- [ ] Existing client config is acceptable to share with the development team; backend permissions remain enforced.
- [ ] Manual two-device results are recorded honestly in `validation.md`; do not mark unperformed cases passed.
