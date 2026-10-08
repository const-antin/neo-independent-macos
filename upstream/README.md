# Vendored inputs

These inputs are kept unchanged; `scripts/build.rb` applies the independent-modifier transformation.

- `neo.keylayout`: `Deutsch (Neo 2)` from the official `neo-layouts.bundle`, downloaded through [Neo's macOS download](https://www.neo-layout.org/Download/). Its embedded edit date is 2022-06-19. Source archive: https://dl.neo-layout.org/neo-layouts.dmg . SHA-256: `6a1bf6ba2ee54b306bf85d7bb5dfaaf0d1ec929108291883d38ddb8649c56dc0`.
- `neo2.json`: pqrs-org/KE-complex_modifications, `public/json/neo2.json` at commit `f8878da1e01b7ffad6cf1150c31f8a1295bcea9b` (byte-identical to the vendored file), maintained by jgosmann. SHA-256: `b80ed56e0c8288e594f68767f91de287c4fbf0c9a74b6d790efad9cd7b9de509`. The source is [on GitHub](https://github.com/pqrs-org/KE-complex_modifications/blob/main/public/json/neo2.json). `KARABINER-LICENSE.txt` preserves its Unlicense.

The Neo project [licenses driver code under GPLv3](https://www.neo-layout.org/Beitragen/Lizenzfragen/). Related macOS work by Jan Gosmann and contributors is available at [jgosmann/neo2-layout-osx](https://github.com/jgosmann/neo2-layout-osx), also with a GPLv3 license. The official snapshot used here has later keypad changes and is not byte-identical to that repository's current file. The project-wide `LICENSE` contains GPLv3.

The modified `.keylayout`, generated rules, generator, tests and documentation are distributed in source form. Newly authored project code is copyright 2026 Konstantin and licensed under GPL-3.0. Upstream authors retain their copyrights and notices. The generated layout is a derivative of the vendored Neo layout; generated rules incorporate the vendored pqrs rules.
