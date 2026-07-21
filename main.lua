local raw_print = print
function print(...)
    if G and G.DEBUG then
        raw_print(...)
    end
end

local nest_ok, nest = pcall(function()
    return require("nest").init({ console = "3ds" })
end)

require "engine.object"
require "engine.node"
require "engine.moveable"
require "engine.sprite"
require "card"
require "deck"
require "hand"
require "joker"
require "joker_catalog"
require "shop_nodes"
require "consumable"
require "game"
require "globals"
require "consumable_catalog"
require "voucher_catalog"
require "topUI"
require "popup"
require "tag"
require("deck_catalog")
local YouWinUI = require "you_win"
local MainMenuUI = require "main_menu_ui"
local DeckViewUI = require "deck_view_ui"
Sfx = require "sfx"

-- Keyboard aliases for gamepad buttons (desktop testing).
local KEY_TO_GAMEPAD = {
    z = "a",
    x = "b",
    c = "x",
    v = "y",
    q = "leftshoulder",
    e = "rightshoulder",
    up = "dpup",
    down = "dpdown",
    left = "dpleft",
    right = "dpright",
    escape = "start",
    rshift = "back",
}

local function key_to_gamepad_button(key)
    return KEY_TO_GAMEPAD[key]
end

function love.load()
    if Sfx and Sfx.preload_game_sounds then
        Sfx.preload_game_sounds()
    end

    G = Game()
    G:enter_main_menu()
    Top = TopUI()

    G.music = love.audio.newSource("resources/sounds/music1_low.ogg", "stream")
    if G.music then
        G.music:setLooping(true)
        if G.apply_music_volume then
            G:apply_music_volume()
        else
            G.music:play()
        end
    end
end

function love.update(dt)
    local speed = (G and G.SETTINGS and tonumber(G.SETTINGS.GAMESPEED)) or 1
    if speed <= 0 then speed = 1 end
    G:update(dt * speed)
    Top:update(dt * speed)
end

function love.draw(screen)
    if G and G.STATE == G.STATES.MENU then
        MainMenuUI.draw_background(G, screen)
    else
        love.graphics.clear(unpack(G.C.BLIND.Big))
    end
    if screen == "bottom" then
        love.graphics.setColor(1, 1, 1)
        G:draw()
    else
        if G and G.STATE == G.STATES.MENU then
            MainMenuUI.draw_top(G)
        elseif G and G.STATE == G.STATES.YOU_WIN then
            YouWinUI.drawTop(G)
        elseif G._deck_view_open then
            DeckViewUI.draw_top(G)
        else
            Top:draw()
        end
    end
end

function love.keypressed(key)
    if key == "f1" then
        if G then G.DEBUG = not G.DEBUG end
        return
    end
    if key == "p" and G and G.DEBUG then
        if G.popups then
            local p = Popup()
            p:spawn("Nope!", "Nope", 160, 120)
            G:addPopup(p)
            Top:addPopup(p)
        end
        return
    end

    if G and G.DEBUG then
        if key == "1" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(1))
        elseif key == "2" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(2))
        elseif key == "3" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(3))
        elseif key == "4" then
            G:add_consumable(G:random_consumable_id_of_kind("tarot"))
       
        elseif key == "5" then
            G.money = G.money + 100
        elseif key == "6" then
            G:addTag("voucher")
        elseif key == "7" and G.give_random_unowned_voucher then
            G:give_random_unowned_voucher()
        elseif key == "8" and G.round_score then
            G.round_score = G.round_score + 100000000
        end
    end

    local button = key_to_gamepad_button(key)
    if button then
        love.gamepadpressed(nil, button)
    end
end

function love.keyreleased(key)
    local button = key_to_gamepad_button(key)
    if button == "a" or button == "b" or button == "y" then
        love.gamepadreleased(nil, button)
    end
end

function love.gamepadpressed(_, button)
    if G and G.STATE == G.STATES.MENU then
        MainMenuUI.handle_button(G, button)
        return
    end

    if button == "start" and G then
        if G.toggle_pause then
            G:toggle_pause()
            return
        end
    end

    if button == "a" and G then
        G._a_held = true
        G._a_press_time = love.timer.getTime()
        if G.enter_card_select_mode and G.ensure_dpad_cursor then
            G:enter_card_select_mode()
        end
    end
    if button == "y" and G then
        G._y_held = true
        G._y_press_time = love.timer.getTime()
        G._y_sweep_seeded = false
    end
    if button == "b" and G then
        G._b_held = true
        G._b_press_time = love.timer.getTime()
    end

    if button == "leftshoulder" and G and G.toggle_jokers_pulled then
        G:toggle_jokers_pulled()
    end
    if button == "rightshoulder" and G and G.toggle_consumables_pulled then
        G:toggle_consumables_pulled()
    end

    if not G then return end
    if G.STATE == G.STATES.YOU_WIN then
        YouWinUI.handle_button(G, button)
        return
    end
    if G.STATE == G.STATES.PAUSED then
        if G.handle_gamepad_pause and G:handle_gamepad_pause(button) then
            return
        end
        return
    end
    if button == "back" and G.toggle_deck_view then
        G:toggle_deck_view()
        return
    end
    if G._deck_view_open then
        if button == "b" or button == "a" or button == "select" then
            G:exit_deck_view()
        end
        return
    end

    if button == "up" or button == "dpup" or button == "down" or button == "dpdown" then
        if G.handle_gamepad_focus_vertical and G:handle_gamepad_focus_vertical(button) then
            return
        end
    end

    if G.STATE == G.STATES.BLIND_SELECT then
        if button == "b" and G.try_gamepad_skip_blind then
            G:try_gamepad_skip_blind()
            return
        end
        if button == "y" and G.try_gamepad_boss_reroll then
            G:try_gamepad_boss_reroll()
            return
        end
        if button == "y" or button == "a" then
            G:start_selected_blind()
        end
        return
    end
    if G.STATE == G.STATES.ROUND_EVAL then
        if button == "y" or button == "a" then
            G:continue_from_round_win()
        end
        return
    end
    if G.STATE == G.STATES.SHOP then
        if G.handle_gamepad_shop and G:handle_gamepad_shop(button) then
            return
        end
        return
    end
    if G.STATE == G.STATES.OPEN_BOOSTER then
        if G.handle_gamepad_booster and G:handle_gamepad_booster(button) then
            return
        end
        if button == "b" and G.end_booster_session then
            G:end_booster_session()
        end
        return
    end
    if G.STATE == G.STATES.SELECTING_HAND then
        if G.handle_gamepad_selecting_hand and G:handle_gamepad_selecting_hand(button) then
            return
        end
    end
end

function love.gamepadreleased(_, button)
    if not G then return end
    local hold_threshold = 0.4

    if button == "a" then
        G._a_held = false
        G._a_press_time = nil
    end

    if button == "y" then
        local press_time = G._y_press_time
        local swept = G._y_sweep_seeded == true
        G._y_held = false
        G._y_press_time = nil
        G._y_sweep_seeded = false
        local tap_threshold = 0.25
        if not swept and press_time and (love.timer.getTime() - press_time) < tap_threshold then
            if G.try_gamepad_hand_sort_tap then
                G:try_gamepad_hand_sort_tap()
            end
        end
    end

    if button == "b" then
        local press_time = G._b_press_time
        if G.STATE == G.STATES.SHOP and press_time
            and (love.timer.getTime() - press_time) >= hold_threshold
            and G.get_gamepad_focus_layer and G:get_gamepad_focus_layer() == "hand" then
            G:continue_from_shop()
        end
        G._b_held = false
        G._b_press_time = nil
    end
end

function love.gamepadaxis(_, axis, value)
    print(axis, value)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    G:touchpressed(id, x, y)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    G:touchmoved(id, x, y, dx, dy)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    G:touchreleased(id, x, y)
end
