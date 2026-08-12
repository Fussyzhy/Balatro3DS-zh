---@class Consumable : Moveable
Consumable = Moveable:extend()
local TooltipDraw = require("tooltip_draw")
local _consumable_missing_atlas_reported = {}

local function consumable_resolve_atlas(name)
    if not name or not G or not G.ASSET_ATLAS then return nil end
    if G.ensure_asset_atlas_loaded then
        G:ensure_asset_atlas_loaded(name)
    end
    return G.ASSET_ATLAS[name]
end

local function consumable_compute_quad(atlas, index)
    if not atlas or not atlas.image or index == nil then return nil, 0, 0 end
    local iw, ih = atlas.image:getDimensions()
    local cell_w, cell_h = atlas.px, atlas.py
    if not cell_w or not cell_h or cell_w <= 0 or cell_h <= 0 then
        return nil, 0, 0
    end
    local cols = math.floor(iw / cell_w)
    if cols <= 0 then return nil, 0, 0 end
    local col = index % cols
    local row = math.floor(index / cols)
    local sx = col * cell_w
    local sy = row * cell_h
    local quad = love.graphics.newQuad(sx, sy, cell_w, cell_h, iw, ih)
    return quad, cell_w, cell_h
end

local function consumable_normalize_edition(raw)
    if raw == nil or raw == "" then return "base" end
    local e = string.lower(tostring(raw))
    if e == "e_negative" or e == "negative" then return "negative" end
    return "base"
end

---@param X number
---@param Y number
---@param def table  -- entry from CONSUMABLE_DEFS
function Consumable:init(X, Y, def)
    self.def = def or {}
    self.id = self.def.id
    self.kind = self.def.kind
    self.name = self.def.name or "Consumable"
    self.sell_cost = (self.kind == "spectral") and 2 or 1
    self.edition = consumable_normalize_edition(self.def.edition)
    self.atlas_name = self.def.atlas or "Tarot"
    self.index = tonumber(self.def.index) or 0
    if self.edition == "negative" then
        self.index = self.index + 56
    end

    local cw, ch = 72, 95
    Moveable.init(self, X or 0, Y or 0, cw, ch)

    self.states.collide.can = false
    self.states.click.can = true
    self.states.drag.can = true
    self.states.visible = true

    self.atlas = consumable_resolve_atlas(self.atlas_name)
    self.quad, self.w, self.h = consumable_compute_quad(self.atlas, self.index)

    if (not self.atlas or not self.atlas.image or not self.quad) and G and self.atlas_name then
        local key = tostring(self.atlas_name) .. ":" .. tostring(self.index)
        if not _consumable_missing_atlas_reported[key] then
            _consumable_missing_atlas_reported[key] = true
            local err = (self.atlas and self.atlas.load_error) and tostring(self.atlas.load_error) or "unknown atlas/quad failure"
            print(string.format("[Consumable] draw fallback for '%s' atlas='%s' idx=%s err=%s",
                tostring(self.name), tostring(self.atlas_name), tostring(self.index), err))
        end
    end

    if self.w and self.h and self.w > 0 and self.h > 0 then
        self.T.w = self.w
        self.T.h = self.h
        if self.VT then
            self.VT.w = self.w
            self.VT.h = self.h
        end
    end
end

function Consumable:get_collision_rect()
    local t = self.VT or self.T
    local s = t.scale or 1
    local w = t.w or 0
    local h = t.h or 0

    local offx = (self.collision_offset and self.collision_offset.x) or 0
    local offy = (self.collision_offset and self.collision_offset.y) or 0

    local scaled_w = w * s
    local scaled_h = h * s

    local delta_x = (w * s * (1 - s)) / 2
    local delta_y = (h * s * (1 - s)) / 2

    local draw_x = t.x + offx
    local draw_y = t.y + offy

    return {
        x = draw_x + delta_x,
        y = draw_y + delta_y,
        w = scaled_w,
        h = scaled_h,
    }
end

function Consumable:draw()
    if not self.states.visible then return end

    local draw_x = self.VT.x + self.collision_offset.x
    local draw_y = self.VT.y + self.collision_offset.y
    local draw_w = (self.VT and self.VT.w) or (self.T and self.T.w) or 72
    local draw_h = (self.VT and self.VT.h) or (self.T and self.T.h) or 95

    love.graphics.push()

    local cx = draw_x + (self.VT.w * self.VT.scale) / 2
    local cy = draw_y + (self.VT.h * self.VT.scale) / 2
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.VT.r)
    love.graphics.scale(self.VT.scale, self.VT.scale)
    love.graphics.translate(-cx, -cy)

    if self.atlas and self.atlas.image and self.quad then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.atlas.image, self.quad, draw_x, draw_y, 0, 1, 1)
    else
        -- Visual fallback helps distinguish "not drawn" vs "texture failed."
        love.graphics.setColor(0.9, 0.25, 0.25, 0.9)
        love.graphics.rectangle("line", draw_x, draw_y, draw_w, draw_h)
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.pop()

    if G and G.draw_node_gamepad_focus_outline then
        G:draw_node_gamepad_focus_outline(self)
    end
end

function Consumable:draw_tooltip_overlay()
    if not self.states.visible or not self:tooltip_is_active() then return end
    local draw_x = self.VT.x + self.collision_offset.x
    local draw_y = self.VT.y + self.collision_offset.y
    self:draw_tooltip(draw_x, draw_y)
end

--- Planet: hand level text. Tarot: optional `def.tooltip` string or list of strings.
---@return string[]
function Consumable:get_tooltip_body_lines()
    local def = self.def or {}
    local localized = nil
    if def.id and I18N.has("consumable." .. tostring(def.id) .. ".description") then
        localized = I18N.content_description("consumable", def.id, nil)
    end
    if def.id == "tarot_fool" and G then
        local out = {}
        local tip = localized or def.tooltip
        if type(tip) == "table" then
            for _, l in ipairs(tip) do
                if (type(l) == "string" and l ~= "") or type(l) == "table" then out[#out + 1] = l end
            end
        elseif type(tip) == "string" and tip ~= "" then
            for line in tip:gmatch("[^\r\n]+") do
                if line ~= "" then out[#out + 1] = line end
            end
        end
        local last_id = G.last_consumable_use_id
        if last_id and CONSUMABLE_DEFS and CONSUMABLE_DEFS[last_id] then
            local last_def = CONSUMABLE_DEFS[last_id]
            local name = I18N.content_name("consumable", last_id, last_def.name or last_id)
            out[#out + 1] = I18N.t("term.fool_current", { name = name })
        end
        if #out > 0 then return out end
    end
    if def.kind == "planet" and type(def.hand) == "string" and def.hand ~= "" then
        return { I18N.t("term.planet_upgrade", { hand = I18N.hand_name(def.hand) }) }
    end
    if def.kind == "tarot" or def.kind == "spectral" then
        local tip = localized or def.tooltip
        if type(tip) == "table" then
            local out = {}
            for _, l in ipairs(tip) do
                if (type(l) == "string" and l ~= "") or type(l) == "table" then out[#out + 1] = l end
            end
            if #out > 0 then return out end
        elseif type(tip) == "string" and tip ~= "" then
            local out = {}
            for line in tip:gmatch("[^\r\n]+") do
                if line ~= "" then out[#out + 1] = line end
            end
            if #out > 0 then return out end
        end
    end
    return {}
end

function Consumable:tooltip_is_active()
    if not G then return false end
    if G.is_hand_scoring_active and G:is_hand_scoring_active() then return false end
    if G._collection_open and G._collection_tooltip_node == self then return true end
    if G.is_card_select_mode and G:is_card_select_mode() then return false end
    if self.shop_offer_slot and G.STATE == G.STATES.SHOP and G.active_tooltip_joker == self then
        return true
    end
    if G.should_draw_gamepad_focus_outline and G:should_draw_gamepad_focus_outline(self) then
        return true
    end
    if G.is_shop_item_selected and G:is_shop_item_selected(self) then
        return true
    end
    if self._booster_choice_index and G.STATE == G.STATES.OPEN_BOOSTER and G.booster_session then
        return tonumber(G.booster_session.active_choice_index) == self._booster_choice_index
    end
    if G.consumables_on_bottom ~= true then
        if self.states.drag.is then return true end
        return false
    end
    if self.states.drag.is then return true end
    local idx = G.active_tooltip_consumable_index
    if idx and G.consumable_nodes and G.consumable_nodes[idx] == self then
        return true
    end
    return false
end

function Consumable:draw_tooltip(draw_x, draw_y)
    local lines = self:get_tooltip_body_lines()
    if #lines == 0 then return end

    local def = self.def or {}
    local title = I18N.content_name("consumable", def.id, self.name or def.name or I18N.t("term.consumable"))
    if G and G.is_discovered and def.id and not G:is_discovered(def.id) then
        title = I18N.t("term.not_discovered")
    end
    local font = G.FONTS.PIXEL.SMALL or love.graphics.getFont()
    local resolved = {}
    for _, line in ipairs(lines) do
        resolved[#resolved + 1] = TooltipDraw.resolve_line(line)
    end
    local card_w = self.VT.w * self.VT.scale
    local card_h = self.VT.h * self.VT.scale
    TooltipDraw.draw_tooltip_layout(font, title, resolved, draw_x, draw_y, card_w, card_h)
end

