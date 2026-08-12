local FontManager = {}

local FONT_PROFILES = {
    en = {
        path = "resources/fonts/m6x11plus.ttf",
        sizes = { small = 11, medium = 22, large = 33 },
        filter = "nearest",
    },
    zh_CN = {
        path = "resources/fonts/NotoSansSC-Bold.ttf",
        sizes = { small = 11, medium = 21, large = 31 },
        filter = "linear",
    },
}

local function release_font(font)
    if font and font.release then
        pcall(function() font:release() end)
    end
end

local function release_font_set(fonts)
    if type(fonts) ~= "table" then return end
    local pixel = fonts.PIXEL
    if type(pixel) ~= "table" then return end
    release_font(pixel.SMALL)
    release_font(pixel.MEDIUM)
    release_font(pixel.LARGE)
end

local function create_font(path, size, filter)
    local ok, font = pcall(love.graphics.newFont, path, size)
    if not ok or not font then return nil end
    if font.setFilter then
        font:setFilter(filter, filter)
    end
    return font
end

local function resolve_profile(language)
    return FONT_PROFILES[language] or FONT_PROFILES.en, FONT_PROFILES[language] and language or "en"
end

function FontManager.build(language)
    local profile, resolved_language = resolve_profile(language)
    local small = create_font(profile.path, profile.sizes.small, profile.filter)
    local medium = create_font(profile.path, profile.sizes.medium, profile.filter)
    local large = create_font(profile.path, profile.sizes.large, profile.filter)

    if not small or not medium or not large then
        release_font(small)
        release_font(medium)
        release_font(large)
        profile = FONT_PROFILES.en
        resolved_language = "en"
        small = assert(create_font(profile.path, profile.sizes.small, profile.filter))
        medium = assert(create_font(profile.path, profile.sizes.medium, profile.filter))
        large = assert(create_font(profile.path, profile.sizes.large, profile.filter))
    end

    return {
        ACTIVE_LANGUAGE = resolved_language,
        ACTIVE_PATH = profile.path,
        PIXEL = {
            SMALL_HEIGHT = small:getHeight(),
            MEDIUM_HEIGHT = medium:getHeight(),
            LARGE_HEIGHT = large:getHeight(),
            SMALL = small,
            MEDIUM = medium,
            LARGE = large,
        },
    }
end

function FontManager.replace(current_fonts, language)
    release_font_set(current_fonts)
    collectgarbage("collect")
    return FontManager.build(language)
end

function FontManager.profile_for(language)
    local profile, resolved_language = resolve_profile(language)
    return {
        language = resolved_language,
        path = profile.path,
        sizes = {
            small = profile.sizes.small,
            medium = profile.sizes.medium,
            large = profile.sizes.large,
        },
    }
end

return FontManager
