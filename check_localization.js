#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { TextDecoder } = require("util");

const ROOT = __dirname;
const errors = [];
const warnings = [];

function read(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), "utf8").replace(/\r\n/g, "\n");
}

function lineNumber(text, index) {
  return text.slice(0, index).split("\n").length;
}

function literalKeys(relativePath) {
  const text = read(relativePath);
  const keys = [];
  const regex = /\["([^"]+)"\]\s*=/g;
  let match;
  while ((match = regex.exec(text))) {
    keys.push({ key: match[1], line: lineNumber(text, match.index) });
  }
  return keys;
}

function literalStrings(relativePath) {
  const text = read(relativePath);
  const values = new Map();
  const regex = /\["([^"]+)"\]\s*=\s*"((?:\\.|[^"\\])*)"/g;
  let match;
  while ((match = regex.exec(text))) {
    values.set(match[1], match[2]);
  }
  return values;
}

function keySet(relativePath) {
  return new Set(literalKeys(relativePath).map((entry) => entry.key));
}

function compareSets(label, expected, actual) {
  const missing = [...expected].filter((key) => !actual.has(key)).sort();
  const extra = [...actual].filter((key) => !expected.has(key)).sort();
  if (missing.length > 0) errors.push(`${label}: missing ${missing.join(", ")}`);
  if (extra.length > 0) errors.push(`${label}: unexpected ${extra.join(", ")}`);
}

function placeholders(value) {
  const out = new Set();
  const regex = /\{([A-Za-z0-9_]+)\}/g;
  let match;
  while ((match = regex.exec(value || ""))) out.add(match[1]);
  return [...out].sort();
}

function comparePlaceholders(label, englishFiles, chineseFiles) {
  const english = new Map();
  const chinese = new Map();
  for (const file of englishFiles) {
    for (const [key, value] of literalStrings(file)) english.set(key, value);
  }
  for (const file of chineseFiles) {
    for (const [key, value] of literalStrings(file)) chinese.set(key, value);
  }
  for (const [key, englishValue] of english) {
    if (!chinese.has(key)) continue;
    const left = placeholders(englishValue).join(",");
    const right = placeholders(chinese.get(key)).join(",");
    if (left !== right) {
      errors.push(`${label}: placeholder mismatch for ${key}: en={${left}} zh_CN={${right}}`);
    }
  }
}

function checkDuplicateLocaleKeys(language, files) {
  const seen = new Map();
  for (const file of files) {
    for (const entry of literalKeys(file)) {
      const previous = seen.get(entry.key);
      if (previous) {
        errors.push(
          `${language}: duplicate key ${entry.key} at ${file}:${entry.line}; first declared at ${previous.file}:${previous.line}`,
        );
      } else {
        seen.set(entry.key, { file, line: entry.line });
      }
    }
  }
}

function section(text, startMarker, endMarker) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) {
    throw new Error(`Could not locate section ${startMarker} ... ${endMarker}`);
  }
  return text.slice(start, end);
}

function idsFromAssignments(text, prefix) {
  const ids = new Set();
  const regex = new RegExp(`^\\s*(${prefix}[a-z0-9_]+)\\s*=\\s*\\{`, "gm");
  let match;
  while ((match = regex.exec(text))) ids.add(match[1]);
  return ids;
}

function idsFromFields(text, prefix) {
  const ids = new Set();
  const regex = new RegExp(`\\bid\\s*=\\s*"(${prefix}[a-z0-9_]+)"`, "g");
  let match;
  while ((match = regex.exec(text))) ids.add(match[1]);
  return ids;
}

function mapIds(relativePath, mapName) {
  const text = read(relativePath);
  const body = section(text, `local ${mapName} = {`, `\n}`);
  const ids = new Set();
  const regex = /^\s*(j_[a-z0-9_]+)\s*=/gm;
  let match;
  while ((match = regex.exec(body))) ids.add(match[1]);
  return ids;
}

function requireContentKeys(label, ids, keys, namespace, fields) {
  for (const id of [...ids].sort()) {
    for (const field of fields) {
      const key = `${namespace}.${id}.${field}`;
      if (!keys.has(key)) errors.push(`${label}: missing ${key}`);
    }
  }
}

function checkUtf8() {
  const decoder = new TextDecoder("utf-8", { fatal: true });
  const localeRoot = path.join(ROOT, "locales");
  const stack = [localeRoot];
  while (stack.length > 0) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.name.endsWith(".lua")) {
        try {
          decoder.decode(fs.readFileSync(fullPath));
        } catch (error) {
          errors.push(`invalid UTF-8: ${path.relative(ROOT, fullPath)}`);
        }
      }
    }
  }
}

function checkRawEnglishDrawCalls() {
  const files = [
    "main_menu_ui.lua",
    "game.lua",
    "deck_catalog.lua",
    "deck_view_ui.lua",
    "collection_ui.lua",
    "shop_ui.lua",
    "booster_pack_ui.lua",
    "game_over_ui.lua",
    "round_win_ui.lua",
    "you_win.lua",
    "topUI.lua",
  ];
  const findings = [];
  const regex = /love\.graphics\.(?:print|printf)\(\s*["']([^"'\r\n]*[A-Za-z][^"'\r\n]*)["']/g;
  for (const file of files) {
    const text = read(file);
    let match;
    while ((match = regex.exec(text))) {
      if (file === "main_menu_ui.lua" && match[1] === "P") continue;
      findings.push(`${file}:${lineNumber(text, match.index)} ${JSON.stringify(match[1])}`);
    }
  }
  if (findings.length > 0) {
    warnings.push(`direct English draw calls (${findings.length}): ${findings.slice(0, 12).join("; ")}`);
  }
}

function main() {
  const baseEnglish = keySet("locales/en.lua");
  const baseChinese = keySet("locales/zh_CN.lua");
  compareSets("base locale parity", baseEnglish, baseChinese);

  const englishFiles = ["locales/en.lua", "locales/content/en/terms.lua"];
  const chineseFiles = [
    "locales/zh_CN.lua",
    "locales/content/zh_CN/terms.lua",
    "locales/content/zh_CN/decks.lua",
    "locales/content/zh_CN/stakes.lua",
    "locales/content/zh_CN/blinds.lua",
    "locales/content/zh_CN/vouchers.lua",
    "locales/content/zh_CN/tags.lua",
    "locales/content/zh_CN/consumables.lua",
    "locales/content/zh_CN/jokers.lua",
  ];
  checkDuplicateLocaleKeys("en", englishFiles);
  checkDuplicateLocaleKeys("zh_CN", chineseFiles);
  comparePlaceholders("locale placeholders", englishFiles, chineseFiles);

  const englishTerms = keySet("locales/content/en/terms.lua");
  const chineseTerms = keySet("locales/content/zh_CN/terms.lua");
  const chineseJokers = keySet("locales/content/zh_CN/jokers.lua");
  for (const key of englishTerms) {
    if (!chineseTerms.has(key) && !chineseJokers.has(key)) {
      errors.push(`terms parity: missing ${key} in zh_CN`);
    }
  }

  const jokerCatalogIds = idsFromAssignments(read("joker_catalog.lua"), "j_");
  const jokerNameIds = mapIds("locales/content/zh_CN/jokers.lua", "names");
  const jokerDescriptionIds = mapIds("locales/content/zh_CN/jokers.lua", "descriptions");
  compareSets("Joker name coverage", jokerCatalogIds, jokerNameIds);
  compareSets("Joker description coverage", jokerCatalogIds, jokerDescriptionIds);

  const consumableCatalogIds = idsFromAssignments(read("consumable_catalog.lua"), "(?:tarot_|planet_|spectral_)");
  const consumableKeys = keySet("locales/content/zh_CN/consumables.lua");
  requireContentKeys("Consumable coverage", consumableCatalogIds, consumableKeys, "consumable", ["name"]);
  const consumableText = read("consumable_catalog.lua");
  const planetIds = idsFromAssignments(consumableText, "planet_");
  const describedConsumables = new Set([...consumableCatalogIds].filter((id) => !planetIds.has(id)));
  requireContentKeys("Consumable coverage", describedConsumables, consumableKeys, "consumable", ["description"]);

  const deckCatalog = read("deck_catalog.lua");
  const deckIds = idsFromFields(section(deckCatalog, "DECK_DEFS = {", "DECK_DEFS_BY_ID"), "b_");
  const stakeIds = idsFromFields(section(deckCatalog, "STAKE_DEFS = {", "STAKE_DEFS_BY_ID"), "stake_");
  requireContentKeys("Deck coverage", deckIds, keySet("locales/content/zh_CN/decks.lua"), "deck", ["name", "description"]);
  requireContentKeys("Stake coverage", stakeIds, keySet("locales/content/zh_CN/stakes.lua"), "stake", ["name", "description"]);

  const voucherIds = idsFromAssignments(read("voucher_catalog.lua"), "v_");
  requireContentKeys("Voucher coverage", voucherIds, keySet("locales/content/zh_CN/vouchers.lua"), "voucher", ["name", "description"]);

  const gameText = read("game.lua");
  const tagIds = idsFromAssignments(section(gameText, "self.P_TAGS = {", "self.tag_undiscovered"), "tag_");
  const blindIds = idsFromAssignments(section(gameText, "self.P_BLINDS = {", "\n    }\nend\n\nfunction Game:draw"), "bl_");
  requireContentKeys("Tag coverage", tagIds, keySet("locales/content/zh_CN/tags.lua"), "tag", ["name", "description"]);
  requireContentKeys("Blind coverage", blindIds, keySet("locales/content/zh_CN/blinds.lua"), "blind", ["name", "description"]);

  for (const key of [
    "hand.flush_five", "hand.flush_house", "hand.five_of_a_kind", "hand.straight_flush",
    "hand.four_of_a_kind", "hand.full_house", "hand.flush", "hand.straight",
    "hand.three_of_a_kind", "hand.two_pair", "hand.pair", "hand.high_card",
    "suit.hearts", "suit.clubs", "suit.diamonds", "suit.spades",
  ]) {
    if (!chineseTerms.has(key)) errors.push(`terminology coverage: missing ${key}`);
  }

  checkUtf8();
  checkRawEnglishDrawCalls();

  if (warnings.length > 0) {
    for (const warning of warnings) console.warn(`WARN: ${warning}`);
  }
  if (errors.length > 0) {
    for (const error of errors) console.error(`ERROR: ${error}`);
    console.error(`Localization validation failed with ${errors.length} error(s).`);
    process.exit(1);
  }
  console.log(`Localization validation passed with ${warnings.length} warning group(s).`);
}

main();
