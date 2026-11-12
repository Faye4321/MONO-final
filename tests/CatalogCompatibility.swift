
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let decoder = JSONDecoder()
let examples = SeedData.itemsWithDemoDates
check(examples.count == 40, "Expected the four sets of ten bundled examples")
check(Set(examples.map(\.id)).count == 40, "Bundled IDs must be unique")

// Simulate archives from before this release, without a collectionID key.
let baselineData = try encoder.encode(examples)
var legacy = try JSONSerialization.jsonObject(with: baselineData) as! [[String: Any]]
for index in legacy.indices { legacy[index].removeValue(forKey: "collectionID") }
let restored = try decoder.decode([CollectibleItem].self, from: JSONSerialization.data(withJSONObject: legacy))
check(restored == examples, "Adding collectionID must not change old objects")

let collectionID = UUID()
var newItem = examples[0]
newItem.collectionID = collectionID
newItem.isUserCreated = true
let roundTrip = try decoder.decode(CollectibleItem.self, from: encoder.encode(newItem))
check(roundTrip.collectionID == collectionID && roundTrip.category == examples[0].category, "Shelf membership must be independent of object format")
check(roundTrip.title == examples[0].title && roundTrip.imageName == examples[0].imageName, "Membership serialization must preserve content and artwork")

let defaults = PersonalCollection.defaults
check(defaults.count == 4 && Set(defaults.map(\.id)).count == 4, "Default shelf IDs must be stable and unique")
check(defaults.map(\.id) == CollectionCategory.allCases.map(PersonalCollection.defaultID), "Legacy objects must map to the same four shelf IDs")
let trashed = PersonalCollection(id: collectionID, name: "Travel memories", layout: .poster, deletedAt: Date(timeIntervalSince1970: 1000))
let trashRoundTrip = try decoder.decode(PersonalCollection.self, from: encoder.encode(trashed))
check(trashRoundTrip == trashed, "Soft-deleted collection must preserve identity, name and deleted state")
var undeleted = trashRoundTrip
undeleted.deletedAt = nil
check(undeleted.id == collectionID, "Restore must preserve membership identity")
check(newItem.collectionID == undeleted.id, "Restored collection must reuse the original item links")
print("PASS: 40-example archive compatibility, independent custom membership, and recoverable collection identity")
