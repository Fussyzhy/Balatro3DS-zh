# Localization Architecture

Balatro3DS keeps gameplay data language-neutral and translates text only when it is displayed.
This document defines the contract for all localization work.

## Supported Languages

- `en`: English and the fallback language.
- `zh_CN`: Simplified Chinese.

Language codes are stable save-file values. Do not rename an existing code after release.

## Translation Keys

Keys use lower-case dot-separated namespaces:

```text
menu.new_run
settings.language
hand.flush
suit.hearts
joker.j_joker.name
joker.j_joker.description
consumable.tarot_fool.name
blind.bl_hook.description
```

Use these top-level namespaces:

- `menu`, `settings`, `controls`, `common`: fixed interface text.
- `hand`, `suit`, `rank`, `term`: shared gameplay terminology.
- `joker`, `consumable`, `deck`, `stake`, `blind`, `voucher`, `tag`: catalog content.
- `tutorial`, `collection`, `shop`, `round`, `game_over`, `win`: screen-specific text.

Keys identify meaning, not the English sentence. A wording change must not require a key change.

## Internal Values

The following values are gameplay protocol and must remain language-neutral:

- Catalog IDs such as `j_joker`, `tarot_fool`, `b_red`, and `v_overstock_norm`.
- Hand names used by scoring and Joker effects, such as `Pair`, `Flush`, and `Straight Flush`.
- Suit and rank values, such as `Hearts`, `Spades`, `Jack`, and `Ace`.
- State names, save keys, event names, atlas names, and edition names.

Never compare translated text in gameplay code. Translate an internal value only at the display boundary.

## Runtime API

All display text must go through the localization module:

```lua
I18N.t("menu.new_run")
I18N.t("round.score", { score = 120, target = 300 })
I18N.content_name("joker", def.id, def.name)
I18N.content_description("joker", def.id, def.tooltip)
I18N.hand_name("Straight Flush")
I18N.suit_name("Hearts")
```

The runtime uses this lookup order:

1. Selected language.
2. English fallback.
3. Explicit fallback passed by the caller.
4. Translation key, so missing entries remain visible during testing.

Parameters use named placeholders such as `{score}` and `{target}`. Placeholder names must match
between every language.

## Catalog Migration

Existing English catalog fields remain in place as compatibility fallbacks during migration. Display
code derives localization keys from the content type and stable ID. Gameplay code may continue using
the original fields where they form part of an internal rule.

Do not place translated copies directly in catalog definitions. Translations belong in `locales/`.

Large catalogs are split into modules under `locales/content/<language>/`:

```text
locales/content/zh_CN/terms.lua
locales/content/zh_CN/decks.lua
locales/content/zh_CN/stakes.lua
locales/content/zh_CN/blinds.lua
locales/content/zh_CN/vouchers.lua
locales/content/zh_CN/tags.lua
locales/content/zh_CN/consumables.lua
locales/content/zh_CN/jokers.lua
```

English catalog fields remain the fallback source of truth. English content modules are needed only
for shared runtime templates that do not already exist in a catalog field.

## Fonts

English uses `m6x11plus`. CJK languages use a language-specific Noto Sans font. Only fonts required by
the active language should be retained at runtime on memory-constrained hardware.

The public font interface remains `G.FONTS.PIXEL.SMALL`, `MEDIUM`, and `LARGE` so screens do not need
to know which font file is active.

## Layout

All translated text must be measured using the active font. Fixed-width controls must either wrap,
select a smaller font, or truncate only when the screen explicitly permits it. CJK wrapping must work
between UTF-8 characters and must not depend on spaces.

Tooltips must use structured color metadata. Parsing English words such as `chips` or `mult` is a
temporary compatibility path, not a localization mechanism.

Use structured lines when a translation needs semantic coloring:

```lua
["joker.j_joker.description"] = {
    { text = "+4 倍率", color_key = "MULT" },
}
```

Supported tooltip color keys include `MULT`, `CHIPS`, `MONEY`, `CHANCE`, `IMPORTANT`, `PURPLE`, and
`RED`. The shared tooltip renderer wraps UTF-8 text between CJK characters, preserves segment colors,
limits the tooltip to the bottom screen, and truncates only when the full content cannot fit.

## Source Encoding

Lua source and locale files are UTF-8. Runtime code should stay ASCII where practical; non-ASCII text
belongs primarily in locale files.

## Verification

Every localization change should verify:

- English and Simplified Chinese contain the same required keys.
- Placeholder sets match across languages.
- Catalog entries resolve to a translated name and description where applicable.
- No translated value is persisted as an internal gameplay identifier.
- Text stays within the `400x240` top screen and `320x240` bottom screen.

Run the automated validation from the repository root:

```sh
node check_localization.js
```

The checker fails on:

- Missing or extra fixed-interface keys between English and Simplified Chinese.
- Duplicate keys and placeholder mismatches.
- Invalid UTF-8 in locale files.
- Missing names or descriptions for required catalog entries.
- Missing shared hand and suit terminology.

It also scans major UI modules for directly drawn English string literals.

## Adding A Language

1. Add the language code to `Localization.SUPPORTED_LANGUAGES` in `localization.lua`.
2. Add `locales/<language>.lua` with every fixed-interface key present in `locales/en.lua`.
3. Add the required modules below `locales/content/<language>/`.
4. Add a font profile in `font_manager.lua`. Keep only the active language fonts loaded at runtime.
5. Run `node check_localization.js` and Lua 5.1 syntax validation.
6. Complete the desktop and 3DS QA checklist before release.

Keep parameter names unchanged across languages. Never translate catalog IDs, hand identifiers, suit
identifiers, save keys, or other values consumed by gameplay code.

## QA Checklist

### Desktop / Emulator

- Start with a new profile in English and Simplified Chinese.
- Switch languages from the pause menu and confirm that the font and visible UI update immediately.
- Restart the game and confirm that each profile restores its own language.
- Visit the main menu, tutorial, deck/stake picker, blind select, shop, booster packs, collection,
  deck view, pause/settings, round win, game over, and victory screens.
- Inspect long Joker, consumable, voucher, blind, tag, deck, enhancement, seal, and edition tooltips.
- Confirm CJK lines wrap without spaces, colored segments remain aligned, and tooltips stay within the
  `320x240` bottom screen.
- Load an existing English save and confirm internal hand, suit, blind, item, and voucher IDs still work.
- Switch back to English and confirm no translation keys are shown to the player.

### Nintendo 3DS Hardware

- Build with the LovePotion/Lovebrew toolchain and launch the generated `.3dsx` on hardware.
- Confirm `NotoSansSC-Bold` loads without an out-of-memory failure and language switching releases the
  previous font objects.
- Repeat the major screen and tooltip checks on both top and bottom displays.
- Verify touch targets, gamepad focus, and text do not overlap at native `400x240` and `320x240` sizes.
- Save, quit, relaunch, and verify the profile language and run snapshot remain compatible.
- Play at least one complete run in each language and inspect score, payout, Boss Blind, dynamic Joker,
  and victory statistics text.

The current development environment does not include LovePotion, Lovebrew, or physical 3DS hardware.
Lua 5.1 syntax and localization data can be checked locally, but hardware validation remains required
before publishing a multilingual release.
