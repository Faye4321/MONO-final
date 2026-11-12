#!/usr/bin/env python3
"""Local data-policy check. Reads app source; uses a temporary Swift file/cache only."""
from pathlib import Path
import subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'MonArchive/CollectionStore.swift').read_text()
def declaration(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == '{': depth += 1
        elif source[index] == '}':
            depth -= 1
            if depth == 0: return source[start:index + 1]
    raise ValueError('Declaration not closed')
cache = declaration('    private struct CatalogCache: Codable')
offer = declaration('    var defaultCleanupOffered: Bool')
fixture = '\nstruct OfferPolicyFixture { var catalogReady: Bool; var sampleOfferEligible: Bool; var sampleChoiceMade: Bool\n' + offer + '\n}\n'
checks = '''
do {
    let pendingID = UUID()
    let revision = UUID()
    let cached = CatalogCache(collections: PersonalCollection.defaults,
        pending: [pendingID: revision], sampleChoiceMade: false, sampleOfferEligible: nil)
    let bytes = try JSONEncoder().encode(cached)
    var old = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
    old.removeValue(forKey: "sampleOfferEligible")
    let recovered = try JSONDecoder().decode(CatalogCache.self, from: JSONSerialization.data(withJSONObject: old))
    check(recovered.pending[pendingID] == revision, "Old pending collection edits must survive the added optional offer flag")
    check(recovered.collections == cached.collections, "Existing catalog records must survive cache migration")
    check(recovered.sampleOfferEligible == nil, "Old accounts must not silently gain signup-only eligibility")
    check(!OfferPolicyFixture(catalogReady: true, sampleOfferEligible: false, sampleChoiceMade: false).defaultCleanupOffered, "Returning accounts must not gain the cleanup offer")
    check(OfferPolicyFixture(catalogReady: true, sampleOfferEligible: true, sampleChoiceMade: false).defaultCleanupOffered, "New registered accounts must see the first-time offer")
    check(!OfferPolicyFixture(catalogReady: true, sampleOfferEligible: true, sampleChoiceMade: true).defaultCleanupOffered, "A completed decision must hide the offer permanently")
    check(!OfferPolicyFixture(catalogReady: false, sampleOfferEligible: true, sampleChoiceMade: false).defaultCleanupOffered, "Do not show the offer before account metadata loads")
    print("PASS: old cache preserves pending edits; signup-only cleanup offer and one-time decision policy")
}
'''
combined = '\n'.join([(ROOT / 'MonArchive/Models.swift').read_text(),
    (ROOT / 'MonArchive/SeedData.swift').read_text(), cache, fixture,
    (ROOT / 'tests/CatalogCompatibility.swift').read_text(), checks])
with tempfile.TemporaryDirectory(prefix='mono-catalog-check-') as folder:
    path = Path(folder) / 'check.swift'
    path.write_text(combined)
    subprocess.run(['swift', '-module-cache-path', str(Path(folder) / 'cache'), str(path)], check=True)
