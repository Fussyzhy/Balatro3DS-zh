--- Role-based 3DS gamepad bindings (A/B/X/Y/L/R/ZL/ZR).
local InputBindings = {}

InputBindings.SLOTS_PER_ROLE = 2

InputBindings.ROLES = {
    "confirm",
    "cancel",
    "use",
    "sort",
    "shoulder_l",
    "shoulder_r",
}

InputBindings.REBINDABLE_BUTTONS = {
    a = true,
    b = true,
    x = true,
    y = true,
    leftshoulder = true,
    rightshoulder = true,
    lefttrigger = true,
    righttrigger = true,
}

InputBindings.DEFAULT_BINDINGS = {
    confirm = "a",
    cancel = "b",
    use = "x",
    sort = "y",
    shoulder_l = "leftshoulder",
    shoulder_r = "rightshoulder",
}

InputBindings.GESTURES = {
    sort_tap_max_ms = 250,
    shop_exit_hold_ms = 400,
    sweep_seed_hold_ms = 250,
}

InputBindings.HOLD_ROLES = {
    confirm = true,
    cancel = true,
    sort = true,
}

local ROLE_LABELS = {
    confirm = "Confirm",
    cancel = "Cancel",
    use = "Use",
    sort = "Sort",
    shoulder_l = "Show Jokers",
    shoulder_r = "Show Consumables",
}

local BUTTON_LABELS = {
    a = "A",
    b = "B",
    x = "X",
    y = "Y",
    leftshoulder = "L",
    rightshoulder = "R",
    righttrigger = "ZR",
    lefttrigger = "ZL",
}

local ROLE_HINTS = {
    confirm = "Tap: Select; Hold+D-pad: Reorder",
    cancel = "Tap: Discard/Sell; Hold: Exit shop",
    use = "Tap: Play / Buy & Use",
    sort = "Tap: Sort; Hold+D-pad: Sweep",
    shoulder_l = "Toggle jokers panel",
    shoulder_r = "Toggle consumables panel",
}

local function copy_bindings(bindings)
    local out = {}
    for _, role in ipairs(InputBindings.ROLES) do
        out[role] = bindings[role]
    end
    return out
end

function InputBindings.default_settings()
    return {
        bindings = copy_bindings(InputBindings.DEFAULT_BINDINGS),
    }
end

function InputBindings.normalize_bindings(data)
    local out = copy_bindings(InputBindings.DEFAULT_BINDINGS)
    if type(data) ~= "table" then return out end

    local used = {}
    local valid = true
    for _, role in ipairs(InputBindings.ROLES) do
        local btn = data[role]
        if type(btn) ~= "string" or not InputBindings.REBINDABLE_BUTTONS[btn] then
            valid = false
            break
        end
        if used[btn] then
            valid = false
            break
        end
        used[btn] = role
        out[role] = btn
    end

    if not valid then
        return copy_bindings(InputBindings.DEFAULT_BINDINGS)
    end
    return out
end

function InputBindings.normalize_controls(data)
    local out = InputBindings.default_settings()
    if type(data) ~= "table" then return out end
    out.bindings = InputBindings.normalize_bindings(data.bindings)
    return out
end

function InputBindings.get_bindings(game)
    local controls = game and game.SETTINGS and game.SETTINGS.CONTROLS
    if controls and type(controls.bindings) == "table" then
        return controls.bindings
    end
    return copy_bindings(InputBindings.DEFAULT_BINDINGS)
end

function InputBindings.get_role_for_button(button, bindings)
    if type(button) ~= "string" or button == "" then return nil end
    bindings = bindings or copy_bindings(InputBindings.DEFAULT_BINDINGS)
    for _, role in ipairs(InputBindings.ROLES) do
        if bindings[role] == button then
            return role
        end
    end
    return nil
end

function InputBindings.get_button_for_role(role, bindings)
    if type(role) ~= "string" then return nil end
    bindings = bindings or copy_bindings(InputBindings.DEFAULT_BINDINGS)
    return bindings[role]
end

function InputBindings.is_role(button, role, bindings)
    if type(role) ~= "string" then return false end
    return InputBindings.get_role_for_button(button, bindings) == role
end

function InputBindings.is_menu_activate(button, bindings)
    return InputBindings.is_role(button, "confirm", bindings)
        or InputBindings.is_role(button, "sort", bindings)
end

function InputBindings.is_menu_back(button, bindings)
    return InputBindings.is_role(button, "cancel", bindings)
        or InputBindings.is_role(button, "use", bindings)
end

function InputBindings.set_role_binding(bindings, role, button)
    if type(role) ~= "string" or not InputBindings.REBINDABLE_BUTTONS[button] then
        return false
    end
    bindings = bindings or copy_bindings(InputBindings.DEFAULT_BINDINGS)
    local other_role = InputBindings.get_role_for_button(button, bindings)
    local prev_button = bindings[role]
    if other_role and other_role ~= role then
        bindings[other_role] = prev_button
    end
    bindings[role] = button
    return true
end

function InputBindings.reset_bindings(bindings)
    local defaults = copy_bindings(InputBindings.DEFAULT_BINDINGS)
    for _, role in ipairs(InputBindings.ROLES) do
        bindings[role] = defaults[role]
    end
    return bindings
end

function InputBindings.role_label(role)
    return ROLE_LABELS[role] or tostring(role or "?")
end

function InputBindings.button_label(button)
    return BUTTON_LABELS[button] or tostring(button or "?")
end

function InputBindings.role_hint(role)
    return ROLE_HINTS[role] or ""
end

function InputBindings.apply_to_game(game)
    if not game then return end
    if type(game.SETTINGS) ~= "table" then return end
    game.SETTINGS.CONTROLS = InputBindings.normalize_controls(game.SETTINGS.CONTROLS)
end

function InputBindings.is_rebindable_button(button)
    return type(button) == "string" and InputBindings.REBINDABLE_BUTTONS[button] == true
end

return InputBindings
