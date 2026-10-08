# SPDX-License-Identifier: GPL-3.0-only
# Copyright 2026 Konstantin
"""Portable semantic comparisons, not a simulation of Karabiner or macOS."""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def decode(text):
    return ''.join(chr(ord(c) - 0xE000) if 0xE000 <= ord(c) < 0xE020 else c for c in text)


class Layout:
    def __init__(self, path):
        raw = path.read_text()
        raw = re.sub(r'&#x([0-9a-f]+);', lambda m: chr(0xE000 + int(m[1], 16))
                     if int(m[1], 16) < 32 else m[0], raw, flags=re.I)
        root = ET.fromstring(raw)
        self.maps = {int(m.attrib['index']): {int(k.attrib['code']): k.attrib for k in m}
                     for m in root.findall('keyMapSet/keyMap')}
        self.actions = {a.attrib['id']: {w.attrib['state']: w.attrib for w in a}
                        for a in root.findall('actions/action')}
        self.terminators = {w.attrib['state']: w.attrib['output'] for w in root.findall('terminators/when')}
        assert len(self.actions) == len(root.findall('actions/action')), 'Duplicate action IDs'
        for entries in self.maps.values():
            for key in entries.values():
                if 'action' in key:
                    assert key['action'] in self.actions
        all_states = {'none'} | set(self.terminators) | {state for action in self.actions.values() for state in action}
        for action in self.actions.values():
            for branch in action.values():
                if 'next' in branch:
                    assert branch['next'] in all_states, branch

    def sequence(self, events):
        state, output = 'none', ''
        for code, index in events:
            key = self.maps[index].get(code)
            if key is None:
                continue
            termination = '' if state == 'none' else self.terminators.get(state, '')
            if 'output' in key:
                output += termination + key['output']
                state = 'none'
            else:
                action = self.actions[key['action']]
                exact = state in action
                branch = action.get(state, action.get('none'))
                assert branch is not None
                output += ('' if exact else termination) + branch.get('output', '')
                state = branch.get('next', 'none')
        return decode(output), state != 'none'


original = Layout(ROOT / 'upstream/neo.keylayout')
custom = Layout(ROOT / 'dist/NeoIndependent.bundle/Contents/Resources/Neo 2 Independent JIS.keylayout')
# Includes ANSI text, the ISO extra key, keypad, and controls mapped on layers.
keys = sorted(set(original.maps[0]) & set(original.maps[4]) & set(original.maps[5]) - {93, 94})
prefixes = {3: (93, 0), 4: (94, 1), 5: (93, 1), 6: (94, 0)}
comparisons = 0


def compare(before, after, label):
    global comparisons
    expected, actual = original.sequence(before), custom.sequence(after)
    assert expected == actual, f'{label}: {expected!r} != {actual!r}'
    comparisons += 1


for code in keys:
    for index in (0, 1, 2, 3, 7, 8, 9):
        compare([(code, index)], [(code, index)], f'base map {index}, code {code}')
    for layer, index in ((3, 4), (4, 1), (5, 5), (6, 5)):
        events = [(code, index)] if layer in (3, 5) else [(121, 5), (code, index)]
        compare(events, [prefixes[layer], (code, 0)], f'layer {layer}, code {code}')
    for layer, index in ((3, 6), (5, 5), (6, 5)):
        events = [(code, index)] if layer != 6 else [(121, 5), (code, index)]
        selector, base = prefixes[layer]
        compare(events, [(selector, base + 2), (code, 2)], f'caps layer {layer}, code {code}')

for first_layer, first_map in ((1, 0), (3, 4), (5, 5)):
    for dead in keys:
        if not original.sequence([(dead, first_map)])[1]:
            continue
        for second_layer, second_map in ((1, 0), (3, 4), (5, 5)):
            for following in keys:
                first = [(dead, 0)] if first_layer == 1 else [prefixes[first_layer], (dead, 0)]
                second = [(following, 0)] if second_layer == 1 else [prefixes[second_layer], (following, 0)]
                compare([(dead, first_map), (following, second_map)], first + second,
                        f'dead key {first_layer}/{second_layer}, {dead}/{following}')

rules = json.loads((ROOT / 'dist/independent-rules.json').read_text())['rules']
assert len(rules) == 4
mappings = [m for rule in rules for m in rule['manipulators']]
for m in mappings:
    gates = [c for c in m.get('conditions', []) if c['type'] == 'input_source_if']
    assert len(gates) == 1
    pattern = gates[0]['input_sources'][0]['input_source_id']
    assert re.search(pattern, 'org.neoindependent.keyboardlayout.jis')
    assert not re.search(pattern, 'com.apple.keylayout.US')
    assert not re.search(pattern, 'local.neo.independent.old')
    for field in ('to', 'to_after_key_up', 'to_if_alone', 'to_if_held_down'):
        for event in m.get(field, []):
            assert 'option' not in event.get('key_code', '')
            assert not any('option' in mod for mod in event.get('modifiers', []))
    output = m.get('to', [])
    if output and output[0].get('key_code') in ('international1', 'international3'):
        assert len(output) == 2
        assert all(e.get('repeat') is False for e in output)

# Mod3 keys must be swallowed, with independent key-up resets and no modifier events.
for m in rules[0]['manipulators']:
    assert m['from']['key_code'] in ('caps_lock', 'backslash')
    assert m['to'][0]['set_variable']['value'] == 1
    assert m['to_after_key_up'][0]['set_variable']['value'] == 0
    assert m['to'][0]['set_variable']['name'] == m['to_after_key_up'][0]['set_variable']['name']
    assert len(m['to']) == 1

# Layer priority: 6 wins with Mod4+Mod3 (including Shift), then 5, then 3.
for key in json.loads((ROOT / 'dist/independent-key-codes.json').read_text()):
    for side in ('left', 'right'):
        entries = [m for m in rules[1]['manipulators'] if m['from']['key_code'] == key and
                   any(c.get('name') == f'neo_independent_mod3_{side}' for c in m['conditions'])]
        assert [m['to'][0]['key_code'] for m in entries] == ['international1', 'international1', 'international3', 'international3']
        assert entries[0]['from']['modifiers']['mandatory'] == ['shift']
        assert entries[2]['to'][0]['modifiers'] == ['left_shift']

cursor = rules[2]['manipulators']
assert cursor[0]['from']['key_code'] == 'right_command'
for key, arrow in [('s', 'left_arrow'), ('d', 'down_arrow'), ('e', 'up_arrow'), ('f', 'right_arrow')]:
    entry = next(m for m in cursor if m['from'].get('key_code') == key)
    assert entry['to'] == [{'key_code': arrow}]
assert not any(m['from'].get('key_code') in ('left_command', 'right_option', 'left_option') for m in mappings)
print(f'PASS: {comparisons} XML translation comparisons; {len(mappings)} mappings checked for gating and synthesized Option events.')
print('These checks do not prove native compilation, event flag delivery, repeat timing, or IDE compatibility.')
