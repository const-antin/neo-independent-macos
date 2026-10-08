# Neo Independent for macOS — experimental

Neo 2 on macOS keeps triggering Option/Alt shortcuts in your IDE? This experimental Karabiner-Elements setup uses Neo symbol layers without mapping Mod3 to Option, avoiding accidental Alt shortcuts while typing.

This project grew out of a practical problem: typing Neo symbols through an Option-based Mod3 setup made IDEs interpret some keystrokes as shortcuts. Here, Caps Lock and the physical backslash key set private Karabiner variables. A custom macOS keyboard layout uses synthetic JIS Yen/Ro keystrokes to select the intended Neo layer. **The generated rules never synthesize Option.**

This removes the implicit Option signal that caused that problem. It is an experimental alternative, with native macOS and application testing still pending. It does **not** promise that every IDE, terminal, remote session, or raw-key listener will handle the resulting event sequence correctly.

## Key bindings

Use physical key positions, regardless of their printed Neo characters.

| Physical key/chord | Function |
| --- | --- |
| Caps Lock **or** backslash (`\`, below Backspace on US ANSI) | Mod3 while held |
| Right Command | Mod4 while held; dedicated to Neo, no Command function |
| Left Command | Normal Command shortcuts |
| Shift | Layer 2 |
| Mod3 | Layer 3: programming symbols |
| Right Command | Layer 4: cursor/navigation and keypad |
| Shift + Mod3 | Layer 5: Greek and other symbols |
| Right Command + Mod3, with or without Shift | Layer 6: mathematical symbols |
| Both Shift keys together | Toggle Caps Lock |

The intended Neo character assignments come from the vendored official macOS layout. This changes the layer mechanism and modifier positions. Backtick is not a Mod4 key; there is no Mod4 lock chord. The ISO extra key remains available as a character key. Physical Option keys retain their normal behavior, so deliberately holding Option can still invoke Option shortcuts.

## Known tradeoffs

- **Selector-based symbol repetition is disabled.** Holding a symbol key emits once. Repeating only the final event would otherwise emit a base-layer character. Cursor arrows, deletion and ordinary single-event keypad mappings retain repetition.
- The selector is a real synthetic key event. A raw-key listener, shortcut engine, terminal or remote client might intercept it. This is not a new system-wide macOS modifier and is not free of all possible event side effects.
- JIS Yen/Ro are absent from standard US ANSI and German ISO keyboards. JIS keyboards, unusual firmware and other remappers may use them; those configurations are outside the initial target.
- Caps Lock and backslash are dedicated Mod3 keys while this input source is active. Right Command is dedicated Mod4. Chords combining Mod3 with Command/Control/Option are not comprehensively mapped or tested.
- Mid-chord input-source changes, two keyboards used together, interrupted key releases, rapid key sequences and macOS dead-key interactions need live testing.
- The generated layout is large because it preserves dead-key states across layer changes. XML equivalence does not prove that macOS will compile or deliver every sequence correctly.

## Install manually

Download this repository's ZIP or clone it. Ready-to-copy files are in [`dist/`](dist/); building is optional. Keep a working US or original Neo input source available for rollback.

1. Install [Karabiner-Elements](https://karabiner-elements.pqrs.org/) and grant the macOS permissions it requests. For the initial US ANSI target, set its virtual keyboard type to **ANSI**.
2. Copy `dist/NeoIndependent.bundle` into `~/Library/Keyboard Layouts/`. Create that folder if needed. This is a distinct input source; it does not replace the official Neo bundle. Log out and back in if macOS does not discover it.
3. Add **Neo 2 Independent JIS** in macOS System Settings → Keyboard → Text Input → Edit → Add Input Source. It may be listed under German. Keep your fallback input source enabled.
4. Copy `dist/independent-rules.json` into `~/.config/karabiner/assets/complex_modifications/` (create the folder if needed).
5. In Karabiner → Complex Modifications, add these four rules **in this order**, above overlapping personal remaps:
   - Neo Independent: private Mod3 keys
   - Neo Independent: layers 3, 5 and 6 without Option
   - Neo Independent: dedicated Right Command cursor layer
   - Neo Independent: toggle Caps Lock with both Shift keys
6. Select **Neo 2 Independent JIS**. Check symbols and cursor keys in a disposable text document before using it for work. Disable any other global remaps of these keys. Stock Neo rules normally target the official input source, but modified personal rules may overlap.

Every rule is gated to this custom input-source ID. Do not replace your entire `karabiner.json` with the asset file. See Karabiner's [complex modifications instructions](https://karabiner-elements.pqrs.org/docs/manual/configuration/configure-complex-modifications/).

### Roll back

Release held keys and select US or your previous Neo input source. Remove the four **Neo Independent** rules in Karabiner if you no longer want them. To uninstall fully, remove this input source in System Settings, then delete its bundle and rule asset. Log out/in if needed. Keep the original Neo files and rules if you want to return to that setup.

## How it works

Karabiner variables track the two Mod3 keys independently and Right Command as Mod4. Symbol mappings emit a silent selector followed by an ordinary key:

| Layer | Karabiner selector | macOS key code |
| --- | --- | --- |
| 3 | `international3` (JIS Yen) | 93 |
| 5 | Shift + `international3` | 93 with Shift |
| 6 | `international1` (JIS Ro) | 94 |
| Special layer-4 text | Shift + `international1` | 94 with Shift |

The `.keylayout` consumes the selector as a dead state and interprets the following key using the original Neo layer. Each existing accent state has a corresponding carrier state, preserving composed characters across layer switches. Standard navigation is emitted directly as arrows, Home/End equivalents, deletion and keypad events, following the upstream rules.

This project requires the custom layout **and** its matching rules. Other revisions using ISO selectors or different input-source IDs are not interchangeable.

## Build and checks

Requires Ruby with `rexml` and Python 3. macOS's system Ruby can build it; newer Ruby installations may need `gem install rexml`.

```sh
ruby scripts/build.rb
python3 tests/verify.py
```

The builder reads vendored inputs and writes only `dist/`. It does not install, activate, download anything or edit your keyboard configuration. The generated artifacts are committed for manual installation. CI rebuilds and verifies the output.

On the initial build, **6,160 XML translation comparisons passed**, covering base maps, layers 3–6, Caps Lock and dead-key transitions; **580 mappings** passed event and input-source checks. These are comparisons of XML state-machine behavior, not native event-delivery tests.

An optional **native-to-native** check is included:

```sh
ruby tests/macos_translation.rb
```

It requires both the official Neo layout and this candidate layout to already be installed and visible to macOS with compiled layout data. It reads them through `UCKeyTranslate`; it never installs, enables or selects a layout, and refuses to substitute XML when native data is unavailable. That check remains pending for this revision. See [TESTING.md](TESTING.md) for application checks and release criteria.

## Sources and license

Based on the [Neo project](https://www.neo-layout.org/), its [official macOS bundle](https://www.neo-layout.org/Download/), the work of [Jan Gosmann and contributors](https://github.com/jgosmann/neo2-layout-osx), and [pqrs's Neo2 Karabiner rules](https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/neo2.json). This is an independent experiment, not an official Neo or Karabiner release.

Project code and the modified layout are GPL-3.0; see [LICENSE](LICENSE). The vendored Karabiner rules retain the Unlicense; see [upstream/KARABINER-LICENSE.txt](upstream/KARABINER-LICENSE.txt). Provenance and input checksums are in [upstream/README.md](upstream/README.md).
