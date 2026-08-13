## Balatro3DS

**English** | [简体中文](README.zh-CN.md)

Balatro3DS is a fan-made port/implementation of the game Balatro targeting the Nintendo 3DS, built with Lua and LÖVE.

### Requirements

- A Nintendo 3DS with homebrew capabilities (for running custom software)
- Node.js (optional, for running localization validation during development)

### Getting Started

#### Controls

- Confirm / select: A
- Cancel / discard / sell: B
- Play / use / buy and use: X
- Sort / reroll shop: Y
- Show Jokers: L
- Show Consumables: R
- Open Deck View: Select
- Pause: Start

Controls can be rebound under **Pause > Settings > Controls**.

#### Languages

Balatro3DS currently supports:

- English (`en`), the fallback language
- Simplified Chinese (`zh_CN`)

Change the display language under **Pause > Settings > Language**. The selected language is saved
per profile and takes effect immediately, including the active font.

#### Running on the 3DS

You can download a release.

##### Packaged Builds
1. Download a release from the Releases page
2. Copy the Balatro3DS.3dsx file into the 3ds folder on the root of your SD Card
3. Open Homebrew launcher
4. Play the game

##### Build from Source

Windows automated build instructions and the manual Linux/macOS process are documented in
[BUILD.md](BUILD.md).

### Localization Development

Localization architecture, key conventions, font requirements, and the QA checklist are documented
in [LOCALIZATION.md](LOCALIZATION.md).

Run the repository validation before committing localization changes:

```sh
node check_localization.js
```

The checker validates locale keys and placeholders, UTF-8 source files, catalog coverage, and direct
English strings drawn by major UI modules.

### License

This project is provided as-is for educational and fan purposes. Check the repository license file for details before redistribution.

