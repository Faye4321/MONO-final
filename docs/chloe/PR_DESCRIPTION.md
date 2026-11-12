# Explore discovery, search and persistent wishlist

Explore previously offered four static recommendations without a save flow. This change adds a connected discover → search/filter → detail → save/remove/undo flow, shared heart state, recoverable loading/error/empty states, and a local persistent wishlist behind injectable repository contracts.

The existing collection calendar, Lab and Profile callbacks remain connected. Search in the personal archive also gains a no-results reset action. Shared changes are limited to ShopPick Codable support, Xcode source registrations, a shared scheme and test/CI configuration.

## Data and review

- The default catalog is the existing bundled sample, with explicit sample-price labels.
- Firebase adapters and authenticated-user lifecycle integration are pending Fei's implementation.
- Custom categories require a shared model agreement; this implementation uses the existing four categories.
- Design reference: `docs/chloe/Explore_Figma_Reference.svg`. Team Figma link: pending.

## Validation

- Passed locally: Xcode plist/source membership checks, asset JSON/shared scheme/SVG validation, design JS syntax, design-board rendering and diff whitespace checks.
- Not run in the delivery environment: Swift compilation, 12 XCTest methods, simulator UI/layout tests and cross-module iOS regression.
- Before marking ready: run `swift test`, simulator Debug/Release builds and `docs/chloe/QA_CHECKLIST.md`; record actual results here.

Reviewers: Crystal for shared project and visual consistency; Fei for repository contracts, account scoping and subsequent Firebase integration.
