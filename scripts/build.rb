# SPDX-License-Identifier: GPL-3.0-only
# Copyright 2026 Konstantin
require 'json'
require 'fileutils'
require 'rexml/document'

PROJECT = File.expand_path('..', __dir__)
ROOT = File.join(PROJECT, 'dist')
FileUtils.mkdir_p(ROOT)
ORIGINAL = File.join(PROJECT, 'upstream', 'neo.keylayout')
# REXML accepts XML 1.0 only. Preserve the XML 1.1 control references while editing.
raw = File.read(ORIGINAL).gsub(/&#x([0-9a-f]+);/i) do |reference|
  n = $1.to_i(16)
  n < 32 ? [0xE000 + n].pack('U') : reference
end
doc = REXML::Document.new(raw)
keyboard = doc.root
keyboard.attributes['name'] = 'Neo 2 Independent JIS'
keyboard.attributes['id'] = '-24562'
actions = keyboard.elements['actions']
maps = keyboard.elements['keyMapSet'].get_elements('keyMap').to_h { |m| [m.attributes['index'].to_i, m] }
original_actions = actions.get_elements('action').to_h { |a| [a.attributes['id'], a] }
original_maps = maps.transform_values(&:deep_clone)

def entry_result(key, actions, state, terminators)
  termination = state == 'none' ? '' : terminators.fetch(state, '')
  return {'output' => termination + key.attributes['output']} if key.attributes['output']
  action = actions.fetch(key.attributes['action'])
  choice = action.get_elements('when').find { |w| w.attributes['state'] == state }
  matched = !choice.nil?
  choice ||= action.get_elements('when').find { |w| w.attributes['state'] == 'none' }
  abort "Missing action result for #{key}" unless choice
  result = choice.attributes.to_h.transform_values(&:value).reject { |k, _| k == 'state' }
  result['output'] = termination + result.fetch('output', '') unless matched || termination.empty?
  result
end

# Yen/Ro selectors are absent from standard US and German keyboards.
# The next ordinary key emits the selected Neo layer, with no Alt event.
layers = {3 => [4, 'none', 93, 'international3'], 4 => [1, 'Ebene 4 und 6', 94, 'international1'], 5 => [5, 'none', 93, 'international3'], 6 => [5, 'Ebene 4 und 6', 94, 'international1']}
original_base = maps[0].get_elements('key').to_h { |k| [k.attributes['code'].to_i, k.deep_clone] }
terminators = keyboard.elements['terminators'].get_elements('when').to_h { |w| [w.attributes['state'], w.attributes['output']] }
states = (['none'] + original_actions.values.flat_map { |a| a.get_elements('when').map { |w| w.attributes['state'] } } + terminators.keys).uniq
carrier_states = {}
layers.each do |layer, (index, state, prefix_code, _)|
  prefix = actions.add_element('action', {'id' => "independent_prefix_#{layer}"})
  states.each_with_index do |incoming, number|
    carrier = "independent_layer_#{layer}_state_#{number}"
    carrier_states[[layer, incoming]] = carrier
    prefix.add_element('when', {'state' => incoming, 'next' => carrier})
    keyboard.elements['terminators'].add_element('when', {'state' => carrier, 'output' => terminators.fetch(incoming, '')})
  end
  target_maps = if [3,6].include?(layer)
    [maps[0], maps[2]]
  elsif [4,5].include?(layer)
    [maps[1], maps[3]]
  else
    [maps[0], maps[1], maps[2], maps[3]]
  end
  target_maps.each do |map|
    old = map.get_elements('key').find { |k| k.attributes['code'].to_i == prefix_code }
    map.delete_element(old) if old
    map.add_element('key', {'code' => prefix_code.to_s, 'action' => "independent_prefix_#{layer}"})
  end
end

codes = original_base.keys.reject { |code| [93, 94].include?(code) }
[0, 1, 2, 3].each do |base_index|
codes.each do |code|
  key = maps[base_index].get_elements('key').find { |k| k.attributes['code'].to_i == code }
  key ||= maps[base_index].add_element('key', {'code' => code.to_s, 'output' => ''})
  if key.attributes['action']
    # Clone per key; shared actions otherwise acquire conflicting layer results.
    action = original_actions.fetch(key.attributes['action']).deep_clone
    action.attributes['id'] = "independent_key_#{base_index}_#{code}"
    actions.add_element(action)
  else
    action = actions.add_element('action', {'id' => "independent_key_#{base_index}_#{code}"})
    action.add_element('when', {'state' => 'none', 'output' => key.attributes['output'] || ''})
  end
  layers.each do |layer, (index, state, _, _)|
    selected_index = layer == 3 && [2,3].include?(base_index) ? 6 : index
    source_key = original_maps[selected_index].get_elements('key').find { |k| k.attributes['code'].to_i == code }
    next unless source_key
    states.each do |incoming|
      source_state = incoming == 'none' ? state : incoming
      result = entry_result(source_key, original_actions, source_state, terminators)
      action.add_element('when', result.merge('state' => carrier_states.fetch([layer, incoming])))
    end
  end
  key.attributes.delete('output')
  key.attributes['action'] = action.attributes['id']
end
end

bundle = File.join(ROOT, 'NeoIndependent.bundle')
resources = File.join(bundle, 'Contents', 'Resources')
FileUtils.mkdir_p(resources)
xml = ''
keyboard.attributes['maxout'] = [3, actions.get_elements('action/when').map { |w| w.attributes['output'].to_s.encode('UTF-16LE').bytesize / 2 }.max].max.to_s
REXML::Formatters::Default.new.write(doc, xml)
xml = xml.gsub(/[\uE000-\uE01F]/) { |c| '&#x%04X;' % (c.ord - 0xE000) }
File.write(File.join(resources, 'Neo 2 Independent JIS.keylayout'), xml)
File.write(File.join(bundle, 'Contents', 'Info.plist'), <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>org.neoindependent.keyboardlayout</string>
  <key>CFBundleName</key><string>Neo Independent</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>KLInfo_Neo 2 Independent JIS</key><dict>
  <key>TISInputSourceID</key><string>org.neoindependent.keyboardlayout.jis</string>
  <key>TISIntendedLanguage</key><string>de</string>
  <key>TICapsLockLanguageSwitchCapable</key><false/>
  </dict></dict></plist>
PLIST

original_rules = JSON.parse(File.read(File.join(PROJECT, 'upstream', 'neo2.json'))).fetch('rules')
neo_source = {'type' => 'input_source_if', 'input_sources' => [{'input_source_id' => '^org\\.neoindependent\\.keyboardlayout\\.'}]}
left = {'type' => 'variable_if', 'name' => 'neo_independent_mod3_left', 'value' => 1}
right = {'type' => 'variable_if', 'name' => 'neo_independent_mod3_right', 'value' => 1}
off = {'type' => 'variable_if', 'name' => 'neo_independent_mod4', 'value' => 0}
on = {'type' => 'variable_unless', 'name' => 'neo_independent_mod4', 'value' => 0}
setters = %w[caps_lock backslash].zip(%w[neo_independent_mod3_left neo_independent_mod3_right]).map do |key, variable|
  {'type' => 'basic', 'from' => {'key_code' => key, 'modifiers' => {'optional' => ['any']}},
   'to' => [{'set_variable' => {'name' => variable, 'value' => 1}}],
   'to_after_key_up' => [{'set_variable' => {'name' => variable, 'value' => 0}}], 'conditions' => [neo_source]}
end
base = JSON.parse(JSON.generate(original_rules[0]))
base['manipulators'].reject! do |m|
  %w[caps_lock backslash right_option grave_accent_and_tilde].include?(m.dig('from', 'key_code')) ||
    m.fetch('from').fetch('simultaneous', []).any? { |k| k['key_code'] == 'grave_accent_and_tilde' }
end
base['manipulators'].each do |m|
  m['conditions'].map! { |c| c['type'] == 'input_source_if' ? neo_source : c }
  m['conditions'].reject! { |c| c['name'] == 'neo2_mod_4' && c['value'] == 2 }
  output = m.fetch('to', [])
  if output.length == 2 && output[0]['key_code'] == 'page_down' && output[0].fetch('modifiers', []).include?('left_option')
    m['to'] = [{'key_code' => 'international1', 'modifiers' => ['left_shift']}, {'key_code' => output[1].fetch('key_code')}]
  elsif output.length == 1 && output[0].fetch('modifiers', []).include?('right_option')
    m['to'] = [{'key_code' => 'international3'}, {'key_code' => output[0].fetch('key_code')}]
  end
end

# Cover all keys in the original layer-6 rule, plus space and accent keys.
key_codes = original_rules[1]['manipulators'].map { |m| m.dig('from', 'key_code') } + %w[spacebar grave_accent_and_tilde]
key_codes.uniq!
symbol_maps = []
key_codes.each do |key|
  [left, right].each do |held|
    [[6, on, false], [5, off, true], [3, off, false]].each do |layer, mod4, shift|
      modifiers = {'optional' => ['caps_lock']}
      modifiers['mandatory'] = ['shift'] if shift
      selector = {'key_code' => layers.fetch(layer)[3]}
      selector['modifiers'] = ['left_shift'] if layer == 5
      symbol_maps << {'type' => 'basic', 'from' => {'key_code' => key, 'modifiers' => modifiers},
        'to' => [selector, {'key_code' => key}],
        'conditions' => [neo_source, held, mod4]}
      if layer == 6
        shifted = JSON.parse(JSON.generate(symbol_maps[-1]))
        shifted['from']['modifiers']['mandatory'] = ['shift']
        symbol_maps.insert(-2, shifted)
      end
    end
  end
end
caps = JSON.parse(JSON.generate(original_rules[2]))
caps['description'] = 'Neo Independent: toggle Caps Lock with both Shift keys'
caps['manipulators'].each { |m| m['conditions'] = [neo_source] }
custom_rules = [
  {'description' => 'Neo Independent: private Mod3 keys', 'manipulators' => setters},
  {'description' => 'Neo Independent: layers 3, 5 and 6 without Option', 'manipulators' => symbol_maps},
  base.merge('description' => 'Neo Independent: dedicated Right Command cursor layer'), caps
]
# Repeating only the last event would drop the layer selector. Until complete
# sequence repetition is implemented, selector-based text emits once per press.
custom_rules.each do |rule|
  rule['manipulators'].each do |m|
    next unless m.fetch('to', []).first && %w[international1 international3].include?(m['to'][0]['key_code'])
    m['to'].each { |event| event['repeat'] = false if event['key_code'] }
  end
end
serialized = JSON.generate(custom_rules).gsub('neo2_mod_4', 'neo_independent_mod4')
custom_rules = JSON.parse(serialized)
File.write(File.join(ROOT, 'independent-rules.json'), JSON.pretty_generate({'title' => 'Neo Independent Modifiers', 'rules' => custom_rules}) + "\n")
File.write(File.join(ROOT, 'independent-key-codes.json'), JSON.pretty_generate(key_codes) + "\n")
abort 'Private layer rules emit Option' if custom_rules.any? { |r| r['manipulators'].any? { |m| m.fetch('to', []).any? { |event| event['key_code'].to_s.include?('option') || event.fetch('modifiers', []).any? { |v| v.include?('option') } } } }
puts "Built independent layout and #{custom_rules.sum { |r| r['manipulators'].length }} mappings; no synthesized Option events."
