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
I18N.item_name("joker", def.id, def.name)
I18N.item_description("joker", def.id, def.tooltip)
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
