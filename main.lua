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

function love.load()
    -- Decode static SFX once; avoids stutter on first play (sources stay in `Sfx` cache).
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
        --[[ local stats = love.graphics.getStats()
        if stats then
            love.graphics.setFont(G.FONTS.PIXEL.MEDIUM)
            if stats.images then
                love.graphics.print(stats.images, 6, 0)
            end
            if stats.canvases then
                love.graphics.print(stats.canvases, 6, 20)
            end
            if stats.texturememory then
                love.graphics.print(stats.texturememory, 6, 40)
            end
        end ]]
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
    end
    if key == "p" and G.DEBUG then
        if G and G.popups then
            local p = Popup()
            p:spawn(30, "chips", 100, 100)
            G:addPopup(p)
            Top:addPopup(p)
        end
    end

    if G.DEBUG then
        if key == "1" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(1))
        elseif key == "2" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(2))
        elseif key == "3" then
            G:add_joker_by_def(G:random_joker_def_id_by_rarity(3))
        elseif key == "4" then
            G:add_joker_by_def("j_astronomer")
        elseif key =="5" then
            G.money = G.money + 100
        elseif key == "6" then
            G:addTag("voucher")
        elseif key == "7" and G.give_random_unowned_voucher then
            G:give_random_unowned_voucher()
        elseif key == "8" and G.round_score then
            G.round_score = G.round_score + 100000000
        end
    end

    if not G then return end
    if key == "escape" then
        if G.toggle_pause then
            G:toggle_pause()
            return
        end
    end

    if key == "rshift" and G.toggle_deck_view then
        G:toggle_deck_view()
        return
    end
    if G._deck_view_open then
        if key == "x" or key == "z" or key == "rshift" then
            G:exit_deck_view()
        end
        return
    end

    if G.STATE == G.STATES.MENU then
        local MainMenuUI = require("main_menu_ui")
        MainMenuUI.handle_button(G, key)
        return
    end
    if G.STATE == G.STATES.YOU_WIN then
        YouWinUI.handle_button(G, key)
        return
    end

    if G.STATE == G.STATES.PAUSED then
        if key == "return" or key == "space" or key == "z" then
            G:exit_pause_menu()
        end
        return
    end
    if G.set_jokers_location then
        -- Allow joker row screen toggle in every gameplay state.
        if key == "up" then
            G:set_jokers_location(true)
            return
        end
        if key == "down" then
            G:set_jokers_location(false)
            return
        end
    end

    if G.STATE ~= G.STATES.SELECTING_HAND then
        return
    end

    if key == "e" and G.hand then
        G.hand:sort_by_rank()
    end
    if key == "r" and G.hand then
        G.hand:sort_by_suit()
    end
    if (key == "l") and G.hand then
        if G.hand:has_selection() then G.hand:discard_selected() end
    end
    if (key == ";") and G.hand then
        if G.hand:has_selection() then 
            G:set_jokers_location(false)
            G.hand:play_selected() 
        end
    end
    if key == "x" and G.deck and G.hand and not G.deck:empty() and not G.hand:is_full() then
        local card = G.deck:draw()
        if card then G.hand:add_card(card) end
    end

end

function love.gamepadpressed(_, button)
    if G and G.STATE == G.STATES.MENU then
        local MainMenuUI = require("main_menu_ui")
        MainMenuUI.handle_button(G, button)
        return
    end

    if button == "start" and G then
        if G.toggle_pause then
            G:toggle_pause()
            return
        end
    end

    -- Hold L = card select mode; quick tap at release discards
    if button == "leftshoulder" and G then
        G._l_held = true
        G._l_press_time = love.timer.getTime()
        if G.enter_card_select_mode then
            if G.STATE == G.STATES.SELECTING_HAND then
                G:enter_card_select_mode()
            elseif G.STATE == G.STATES.OPEN_BOOSTER and G.booster_session and G.booster_session.hand_for_tarot then
                G:enter_card_select_mode()
            end
        end
    end
    if button == "rightshoulder" and G then
        G._r_held = true
        G._r_press_time = love.timer.getTime()
        G._r_dpad_used = false
    end

    if not G then return end
    if G.STATE == G.STATES.YOU_WIN then
        YouWinUI.handle_button(G, button)
        return
    end
    if G.STATE == G.STATES.PAUSED then
        if button == "a" or button == "y" then
            G:exit_pause_menu()
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

    if button == "up" or button == "dpup" then
        if G._l_held and G.hand and G.STATE == G.STATES.SELECTING_HAND then
            local node = G.dpad_cursor_node and G:dpad_cursor_node()
            if node then G.hand:toggle_selection(node) end
        elseif G.STATE == G.STATES.OPEN_BOOSTER and G.is_card_select_mode and G:is_card_select_mode()
            and G.handle_gamepad_booster and G:handle_gamepad_booster(button) then
            -- booster hand card-select toggle
        elseif G.STATE == G.STATES.SHOP and G.handle_gamepad_shop and G:handle_gamepad_shop(button) then
            -- layer toggle consumed
        elseif G.set_jokers_location then
            G:set_jokers_location(true)
        end
    elseif button == "down" or button == "dpdown" then
        if G._l_held and G.hand and G.STATE == G.STATES.SELECTING_HAND then
            local node = G.dpad_cursor_node and G:dpad_cursor_node()
            if node then G.hand:toggle_selection(node) end
        elseif G.STATE == G.STATES.SHOP and G.handle_gamepad_shop and G:handle_gamepad_shop(button) then
            -- layer toggle consumed
        elseif G.set_jokers_location then
            G:set_jokers_location(false)
        end
    end

    if G.STATE == G.STATES.BLIND_SELECT then
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
        if button == "y" or button == "a" then
            G:continue_from_shop()
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
    if G.STATE ~= G.STATES.SELECTING_HAND then
        return
    end

    -- D-pad left/right: L / L+R repeat in Game:update_dpad_horizontal_repeat
    if (button == "l" or button == "dpleft") and G.hand then
        if G._l_held then
            -- handled while held in update loop
        else
            G.hand:sort_by_rank()
        end
    end
    if (button == "r" or button == "dpright") and G.hand then
        if G._l_held then
            -- handled while held in update loop
        else
            G.hand:sort_by_suit()
        end
    end
    if (button == "rightshoulder" and G._l_held) then
            local node = G:dpad_cursor_move(0)
            if node then G.hand:toggle_selection(node) end
    end
    if button == "x" and G.hand and G.hand:has_selection() then
        G.hand:discard_selected()
    end
    if (button == "rightshoulder" or button == "y") and G.hand and G.hand:has_selection() then
        if not (button == "rightshoulder" and G._l_held) then
            G:set_jokers_location(false)
            G.hand:play_selected()
            G._r_held = false
        end
    end
    if (button == "b") and G and G.deck and G.hand and not G.deck:empty() and not G.hand:is_full() then
        local card = G.deck:draw()
        if card then G.hand:add_card(card) end
    end
end

function love.gamepadreleased(_, button)
    if not G then return end
    if button == "leftshoulder" then
        local tap_threshold = 0.25
        local press_time = G._l_press_time
        if press_time and (love.timer.getTime() - press_time) < tap_threshold then
            if G.STATE == G.STATES.SELECTING_HAND and G.hand and G.hand:has_selection() then
                G.hand:discard_selected()
            end
        end
        G._l_held = false
        G._l_press_time = nil
    end
    if button == "rightshoulder" then
        local tap_threshold = 0.25
        local press_time = G._r_press_time
        if G._l_held and G.is_card_select_mode and G:is_card_select_mode() and not G._r_dpad_used then
            if press_time and (love.timer.getTime() - press_time) < tap_threshold then
                local node = G.dpad_cursor_node and G:dpad_cursor_node()
                if node and G.hand then
                    G.hand:toggle_selection(node)
                end
            end
        end
        G._r_held = false
        G._r_press_time = nil
        G._r_dpad_used = false
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
