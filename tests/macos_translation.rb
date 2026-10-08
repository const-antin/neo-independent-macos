# SPDX-License-Identifier: GPL-3.0-only
# Copyright 2026 Konstantin
require 'fiddle/import'
module CF
  extend Fiddle::Importer
  dlload '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation'
  extern 'void* CFURLCreateFromFileSystemRepresentation(void*, char*, long, char)'
  extern 'long CFArrayGetCount(void*)'
  extern 'void* CFArrayGetValueAtIndex(void*, long)'
  extern 'char CFStringGetCString(void*, char*, long, unsigned int)'
  extern 'void* CFDataGetBytePtr(void*)'
end
module TIS
  extend Fiddle::Importer
  dlload '/System/Library/Frameworks/Carbon.framework/Carbon'
  extern 'void* TISCreateInputSourceList(void*, char)'
  extern 'void* TISGetInputSourceProperty(void*, void*)'
  extern 'int UCKeyTranslate(void*, unsigned short, unsigned short, unsigned int, unsigned int, unsigned int, void*, unsigned int, void*, void*)'
end
def property(name)
  Fiddle::Pointer.new(TIS.handler[name])[0, Fiddle::SIZEOF_VOIDP].unpack1('J')
end
def cf_string(pointer)
  buffer = "\0" * 4096
  return '' if pointer.null?
  CF.CFStringGetCString(pointer, buffer, buffer.bytesize, 0x08000100)
  buffer.split("\0").first
end
# Read registered layouts only; never register, enable or select an input source.
sources = TIS.TISCreateInputSourceList(nil, 1)
layouts = {}
CF.CFArrayGetCount(sources).times do |i|
  source = CF.CFArrayGetValueAtIndex(sources, i)
  identifier = cf_string(TIS.TISGetInputSourceProperty(source, property('kTISPropertyInputSourceID')))
  next unless identifier.match?(/neo2|neo 2|neo\.deutsch\(neo2\)/i) || identifier == 'org.neoindependent.keyboardlayout.jis'
  puts "Discovered candidate: #{identifier}"
  data = TIS.TISGetInputSourceProperty(source, property('kTISPropertyUnicodeKeyLayoutData'))
  if data.null?
    puts 'No compiled layout data available for candidate'
    next
  end
  layouts[identifier == 'org.neoindependent.keyboardlayout.jis' ? :custom : :original] = CF.CFDataGetBytePtr(data)
  puts "Compiled layout: #{identifier}"
end
abort 'Original compiled layout is required' unless layouts[:original]
abort 'Install the candidate bundle and log out/in before running native checks; no XML fallback is used.' unless layouts[:custom]
def translate(layout, code, modifiers, state)
  length = "\0" * 4
  text = "\0" * 512
  status = TIS.UCKeyTranslate(layout, code, 0, modifiers, 40, 0, state, 255, length, text)
  abort "Translation failed: #{status}" unless status == 0
  text.byteslice(0, length.unpack1('L') * 2).force_encoding('UTF-16LE').encode('UTF-8')
end
def sequence(layout, events)
  state = "\0" * 4
  output = events.map { |code, modifiers| translate(layout, code, modifiers, state) }.join
  [output, (state.unpack1('L') & 0xFFFF) != 0]
end
KEYS = {'a'=>0,'s'=>1,'d'=>2,'f'=>3,'h'=>4,'g'=>5,'z'=>6,'x'=>7,'c'=>8,'v'=>9,'non_us_backslash'=>10,'b'=>11,'q'=>12,'w'=>13,'e'=>14,'r'=>15,'y'=>16,'t'=>17,'1'=>18,'2'=>19,'3'=>20,'4'=>21,'6'=>22,'5'=>23,'equal_sign'=>24,'9'=>25,'7'=>26,'hyphen'=>27,'8'=>28,'0'=>29,'close_bracket'=>30,'o'=>31,'u'=>32,'open_bracket'=>33,'i'=>34,'p'=>35,'l'=>37,'j'=>38,'quote'=>39,'k'=>40,'semicolon'=>41,'comma'=>43,'slash'=>44,'n'=>45,'m'=>46,'period'=>47,'spacebar'=>49,'grave_accent_and_tilde'=>50,'keypad_period'=>65,'keypad_asterisk'=>67,'keypad_plus'=>69,'keypad_num_lock'=>71,'keypad_slash'=>75,'keypad_hyphen'=>78,'keypad_0'=>82,'keypad_1'=>83,'keypad_2'=>84,'keypad_3'=>85,'keypad_4'=>86,'keypad_5'=>87,'keypad_6'=>88,'keypad_7'=>89,'keypad_8'=>91,'keypad_9'=>92}
comparisons = 0
failures = []
KEYS.each do |name, code|
  {3=>[[code,8]],4=>[[121,10],[code,2]],5=>[[code,10]],6=>[[121,10],[code,10]]}.each do |layer, original_events|
    custom_prefix = {3=>[93,0],4=>[94,2],5=>[93,2],6=>[94,0]}.fetch(layer)
    expected = sequence(layouts[:original], original_events)
    actual = sequence(layouts[:custom], [custom_prefix,[code,0]])
    comparisons += 1
    failures << "Layer #{layer}, #{name}: #{expected.inspect} != #{actual.inspect}" unless expected == actual
  end
end
# Normal text and shortcuts must retain the original translation.
KEYS.each do |name, code|
  [0,2,4,6,1,3,16,18].each do |modifier|
    expected = sequence(layouts[:original], [[code,modifier]])
    actual = sequence(layouts[:custom], [[code,modifier]])
    comparisons += 1
    failures << "Base #{modifier}, #{name}: #{expected.inspect} != #{actual.inspect}" unless expected == actual
  end
end
# Check held Caps Lock on symbol layers.
KEYS.each do |name, code|
  {3=>[[code,12]],5=>[[code,14]],6=>[[121,14],[code,14]]}.each do |layer, original_events|
    custom_prefix = {3=>[93,4],5=>[93,6],6=>[94,4]}.fetch(layer)
    expected = sequence(layouts[:original], original_events)
    actual = sequence(layouts[:custom], [custom_prefix,[code,4]])
    comparisons += 1
    failures << "Caps layer #{layer}, #{name}: #{expected.inspect} != #{actual.inspect}" unless expected == actual
  end
end
# Check accents in layers 1, 3 and 5, including transitions between layers.
{1=>0,3=>8,5=>10}.each do |first_layer, first_modifier|
  KEYS.values.each do |dead|
    first = sequence(layouts[:original], [[dead,first_modifier]])
    next unless first[1]
    {1=>0,3=>8,5=>10}.each do |second_layer, second_modifier|
      KEYS.values.each do |following|
        expected = sequence(layouts[:original], [[dead,first_modifier],[following,second_modifier]])
        first_events = first_layer==1 ? [[dead,0]] : [{3=>[93,0],5=>[93,2]}.fetch(first_layer),[dead,0]]
        next_events = second_layer==1 ? [[following,0]] : [{3=>[93,0],5=>[93,2]}.fetch(second_layer),[following,0]]
        actual = sequence(layouts[:custom], first_events+next_events)
        comparisons += 1
        failures << "Accent layers #{first_layer}/#{second_layer}, #{dead}/#{following}: #{expected.inspect} != #{actual.inspect}" unless expected == actual
      end
    end
  end
end
puts "Native macOS translation comparisons: #{comparisons}; failures: #{failures.length}"
puts failures.first(30)
abort 'Native layout checks failed' unless failures.empty?
