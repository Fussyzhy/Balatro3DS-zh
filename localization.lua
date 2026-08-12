local Localization = {}

Localization.DEFAULT_LANGUAGE = "en"
Localization.SUPPORTED_LANGUAGES = { "en", "zh_CN" }

local locale_cache = {}
local current_language = Localization.DEFAULT_LANGUAGE

local function is_supported(language)
    if type(language) ~= "string" then return false end
    for _, code in ipairs(Localization.SUPPORTED_LANGUAGES) do
        if code == language then return true end
    end
    return false
end

local function load_locale(language)
    if locale_cache[language] then return locale_cache[language] end
    local ok, locale = pcall(require, "locales." .. language)
    if not ok or type(locale) ~= "table" then
        locale = {}
    end
    locale_cache[language] = locale
    return locale
end

local function lookup(locale, key)
    if type(locale) ~= "table" or type(key) ~= "string" then return nil end
    if locale[key] ~= nil then return locale[key] end

    local value = locale
    for part in key:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
        if value == nil then return nil end
    end
    return value
end

local function interpolate_string(value, params)
    if type(value) ~= "string" or type(params) ~= "table" then return value end
    return (value:gsub("{([%w_]+)}", function(name)
        local replacement = params[name]
        if replacement == nil then return "{" .. name .. "}" end
        return tostring(replacement)
    end))
end

local function interpolate_value(value, params)
    if type(value) == "string" then
        return interpolate_string(value, params)
    end
    if type(value) ~= "table" then return value end

    local out = {}
    for key, item in pairs(value) do
        out[key] = interpolate_value(item, params)
    end
    return out
end

function Localization.is_supported(language)
    return is_supported(language)
end

function Localization.get_language()
    return current_language
end

function Localization.set_language(language)
    if not is_supported(language) then
        current_language = Localization.DEFAULT_LANGUAGE
        return false
    end
    current_language = language
    load_locale(language)
    return true
end

function Localization.available_languages()
    local out = {}
    for i, code in ipairs(Localization.SUPPORTED_LANGUAGES) do
        out[i] = code
    end
    return out
end

function Localization.has(key, language)
    local code = is_supported(language) and language or current_language
    return lookup(load_locale(code), key) ~= nil
end

function Localization.t(key, params, explicit_fallback)
    if type(params) ~= "table" then
        if explicit_fallback == nil and params ~= nil then
            explicit_fallback = params
        end
        params = nil
    end

    local selected = lookup(load_locale(current_language), key)
    local english = lookup(load_locale(Localization.DEFAULT_LANGUAGE), key)
    local value = selected
    if value == nil then value = english end
    if value == nil then value = explicit_fallback end
    if value == nil then value = tostring(key or "") end
    return interpolate_value(value, params)
end

function Localization.item_name(kind, id, fallback)
    return Localization.t(string.format("%s.%s.name", tostring(kind), tostring(id)), nil, fallback)
end

function Localization.item_description(kind, id, fallback)
    return Localization.t(string.format("%s.%s.description", tostring(kind), tostring(id)), nil, fallback)
end

load_locale(Localization.DEFAULT_LANGUAGE)

return Localization
