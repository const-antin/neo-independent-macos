# Validation and remaining work

## Automated checks

`python3 tests/verify.py` compares the generated XML state machine to the vendored original, including normal text, symbol layers, Caps Lock and two-key accent transitions. It checks rule gating, independent Mod3 key-up resets, layer priority, dedicated Right Command navigation, selector repetition suppression and absence of synthesized Option events.

The evaluator handles the action/output/next/terminator subset used by these files. It does not emulate Karabiner's matching engine, macOS event timing, full modifier delivery, or the native keyboard-layout compiler. A test failure should block publishing an updated generated artifact. A pass does not establish application compatibility.

`ruby tests/macos_translation.rb` compares already registered native layouts using Carbon's `UCKeyTranslate` for the ANSI keyboard type. Both layouts must expose compiled data. No XML fallback is allowed. It tests translation, not actual physical keyboard delivery. Neither test changes the selected input source.

## Status for the initial JIS-only revision

| Check | Status |
| --- | --- |
| Ruby build and syntax | Passed locally |
| XML translation equivalence | 6,160 comparisons passed |
| Rule invariants | 580 mappings checked |
| Karabiner distribution lint and bundle Info.plist syntax | Passed locally |
| Native compilation and native-to-native translation | Pending |
| Karabiner live event flags and modifier release timing | Pending |
| IDEs, terminals, remote clients | Pending |
| ISO/JIS hardware and multiple keyboards | Pending |

An earlier ISO-selector prototype was compared against the native original using an XML evaluator for the candidate. That result is not native-to-native validation of this JIS-only revision.

## Manual checks before recommending daily use

Record macOS and Karabiner versions, keyboard geometry, input-source ID, app version, shortcut settings and the tested commit. Use a disposable document.

1. In Karabiner EventViewer, inspect incoming keys and variables. In an app-level event viewer, inspect the delivered selector/body events and modifier flags. Mod3 alone should emit no Option flag; deliberately holding physical Option should still be visible.
2. Verify layer-3 programming symbols, layer-5 Greek characters, layer-6 mathematical symbols and special layer-4 characters against Neo diagrams. Check each Mod3 side separately and together; releasing one side must leave the other active.
3. Check accents, compose sequences, switching layers after accents, space termination and rapid alternation between symbol and ordinary text. Verify that no silent selector state escapes into the next unrelated character.
4. Check arrow repeat, Shift-selection, Command-navigation, Home/End equivalents, Backspace/Delete, keypad behavior and both-Shift Caps Lock. Confirm that holding a selector-based symbol emits only once.
5. Check Left Command shortcuts, physical Option shortcuts, US input-source fallback, application input-source switching and remapper conflicts. Test switching sources mid-chord and unplugging a keyboard while a modifier is held.
6. Test representative apps: TextEdit, VS Code, a JetBrains IDE, Terminal, iTerm2, a browser, Emacs/MacVim and any remote desktop client you use. In terminals, test both Option-as-Meta and ordinary Option settings. In IDEs, test actual bound shortcuts as well as text entry.

Report the physical chord, expected character/action, observed output or shortcut, and whether a selector or modifier was intercepted. Avoid including private text or logs containing secrets.

## Work needed for broader adoption

Native compiler validation, end-to-end event tests, reliable complete-sequence repetition, defined shortcut-chord behavior, interrupted-release recovery and hardware coverage are open work. Eliminating synthetic Option improves one mechanism; it does not make this implementation strictly better for every workflow.
