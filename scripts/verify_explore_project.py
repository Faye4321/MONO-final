#!/usr/bin/env python3
"""Structural checks only. This script does not compile or execute Swift."""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pbx = (root / 'MonArchive.xcodeproj/project.pbxproj').read_text()
# Parse the OpenStep plist used by Xcode, including comments and quoted tokens.
pattern = re.compile(r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', re.S)
tokens = [m.group() for m in pattern.finditer(pbx) if not m.group().isspace() and not m.group().startswith(('/*','//'))]
index = 0

def value():
    global index
    token = tokens[index]; index += 1
    if token == '{':
        result = {}
        while tokens[index] != '}':
            key = value()
            assert tokens[index] == '='; index += 1
            assert key not in result, f'Duplicate key {key}'
            result[key] = value()
            assert tokens[index] == ';'; index += 1
        index += 1
        return result
    if token == '(':
        result = []
        while tokens[index] != ')':
            result.append(value())
            if tokens[index] == ',': index += 1
        index += 1
        return result
    return token[1:-1] if token.startswith('"') else token

project = value()
assert index == len(tokens)
objects = project['objects']
for key, obj in objects.items():
    assert re.fullmatch('[0-9A-F]{24}', key), key
    for field in ['children', 'files', 'buildPhases', 'targets', 'buildConfigurations']:
        for reference in obj.get(field, []):
            assert reference in objects, (key, field, reference)
    if 'fileRef' in obj: assert obj['fileRef'] in objects
refs = {obj['path']: key for key, obj in objects.items() if obj.get('isa') == 'PBXFileReference'}
sources = objects['C10000000000000000000002']['files']
compiled = [objects[objects[key]['fileRef']]['path'] for key in sources]
assert len(compiled) == len(set(compiled)), 'Duplicate compiled sources'
for file in (root/'MonArchive/Explore').glob('*.swift'):
    assert file.name in refs and compiled.count(file.name) == 1, file
# Verify every source file exists, including baseline files.
for name in compiled:
    assert (root/'MonArchive'/name).exists() or (root/'MonArchive/Explore'/name).exists(), name
ET.parse(root/'MonArchive.xcodeproj/xcshareddata/xcschemes/MonArchive.xcscheme')
ET.parse(root/'docs/chloe/Explore_Figma_Reference.svg')
for path in (root/'MonArchive/Assets.xcassets').rglob('Contents.json'):
    json.loads(path.read_text())
assert len(list((root/'MonArchive/Explore').glob('*.swift'))) == 6
assert 'Codable' in (root/'MonArchive/ShopPicks.swift').read_text().split('struct ShopPick:',1)[1].split('{',1)[0]
count = sum(len(re.findall(r'func test\w+',p.read_text())) for p in (root/'Tests/ExploreCoreTests').glob('*.swift'))
print(f'PASS: Xcode plist parsed; all {len(compiled)} Swift source memberships resolve; shared scheme, SVG, and asset JSON are well formed.')
print(f'Found {count} XCTest methods. Swift compilation, XCTest execution and iPhone simulator QA are NOT performed by this script.')
