-- Demon Hunter PvP Plugin: Main

-- Import required modules
---@type enums
local enums = require("common/enums")

---@type pvp_helper
local pvp_helper = require("common/utility/pvp_helper")

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

---@type plugin_helper
local plugin_helper = require("common/utility/plugin_helper")

---@type control_panel_helper
local control_panel_helper = require("common/utility/control_panel_helper")

---@type key_helper
local key_helper = require("common/utility/key_helper")

---@type target_selector
local target_selector = require("common/modules/target_selector")

---@type color
local color = require("common/color")

-- Import plugin modules
local RotationLogic = require("rotation_logic")
local plugin_data = require("plugin_data")

-- Menu elements
local menu_elements = {
    main_tree = core.menu.tree_node(),
    keybinds_tree = core.menu.tree_node(),
    settings_tree = core.menu.tree_node(),
    
    -- Main toggles
    enable_script = core.menu.checkbox(false, "dh_enable_script"),
    enable_toggle = core.menu.keybind(999, false, "dh_toggle_script"),
    
    -- PvP Settings
    auto_interrupt = core.menu.checkbox(true, "dh_auto_interrupt"),
    auto_defensives = core.menu.checkbox(true, "dh_auto_defensives"),
    auto_mobility = core.menu.checkbox(true, "dh_auto_mobility"),
    auto_cc = core.menu.checkbox(false, "dh_auto_cc"),
    
    -- Burst Settings
    auto_burst = core.menu.checkbox(true, "dh_auto_burst"),
    meta_health_threshold = core.menu.slider_float(0.1, 0.8, 0.4, "dh_meta_threshold"),
    eye_beam_enemies = core.menu.slider_int(1, 5, 2, "dh_eye_beam_enemies"),
    
    -- Defensive Settings
    blur_health_threshold = core.menu.slider_float(0.1, 0.8, 0.6, "dh_blur_threshold"),
    netherwalk_health_threshold = core.menu.slider_float(0.1, 0.6, 0.3, "dh_netherwalk_threshold"),
    
    -- Visual
    draw_plugin_state = core.menu.checkbox(true, "dh_draw_state"),
    draw_fury_bar = core.menu.checkbox(true, "dh_draw_fury"),
    
    -- Target Selector Override
    ts_override = core.menu.checkbox(true, "dh_ts_override"),
}

-- Override target selector settings for DH PvP
local is_ts_overridden = false
local function override_ts_settings()
    if is_ts_overridden then
        return
    end
    
    if not menu_elements.ts_override:get_state() then
        return
    end
    
    -- Set optimal range for DH
    target_selector.menu_elements.settings.max_range_damage:set(20)
    
    -- Prioritize multiple targets for cleave potential
    target_selector.menu_elements.damage.weight_multiple_hits:set(true)
    target_selector.menu_elements.damage.slider_weight_multiple_hits:set(3)
    target_selector.menu_elements.damage.slider_weight_multiple_hits_radius:set(8)
    
    -- Prioritize low health targets
    target_selector.menu_elements.damage.weight_low_health:set(true)
    target_selector.menu_elements.damage.slider_weight_low_health:set(5)
    
    is_ts_overridden = true
end

-- Main update function
local function on_update()
    -- Control Panel Drag & Drop
    control_panel_helper:on_update(menu_elements)
    
    local local_player = core.object_manager.get_local_player()
    if not local_player then
        return
    end
    
    -- Check if script is enabled
    if not menu_elements.enable_script:get_state() then
        return
    end
    
    -- Check toggle state
    if not plugin_helper:is_toggle_enabled(menu_elements.enable_toggle) then
        return
    end
    
    -- Don't run while casting or channeling
    if local_player:get_active_spell_cast_end_time() > 0.0 then
        return
    end
    
    if local_player:get_active_channel_cast_end_time() > 0.0 then
        return
    end
    
    -- Don't run while mounted
    if local_player:is_mounted() then
        return
    end
    
    -- Override target selector settings
    override_ts_settings()
    
    -- Get targets
    local targets_list = target_selector:get_targets()
    local is_defensive_allowed = plugin_helper:is_defensive_allowed()
    
    -- Handle each target
    for index, target in ipairs(targets_list) do
        -- Skip invalid targets
        if not target or not target:is_valid() then
            goto continue
        end
        
        -- Skip out of combat targets
        if not unit_helper:is_in_combat(target) then
            goto continue
        end
        
        -- Skip damage immune targets
        if pvp_helper:is_damage_immune(target, pvp_helper.damage_type_flags.PHYSICAL) then
            goto continue
        end
        
        -- Skip CC'd targets that we shouldn't break
        if pvp_helper:is_crowd_controlled(target, pvp_helper.cc_flags.combine("DISORIENT", "INCAPACITATE", "SAP"), 1000) then
            goto continue
        end
        
        -- Execute rotation logic
        if RotationLogic:execute(local_player, target) then
            return true
        end
        
        ::continue::
    end
end

-- Render function for visual feedback
local function on_render()
    local local_player = core.object_manager.get_local_player()
    if not local_player then
        return
    end
    
    if not menu_elements.enable_script:get_state() then
        return
    end
    
    -- Draw plugin state
    if menu_elements.draw_plugin_state:get_state() then
        if not plugin_helper:is_toggle_enabled(menu_elements.enable_toggle) then
            plugin_helper:draw_text_character_center("DH PvP: DISABLED", color.red(), -30)
        else
            plugin_helper:draw_text_character_center("DH PvP: ACTIVE", color.green(), -30)
        end
    end
    
    -- Draw fury bar
    if menu_elements.draw_fury_bar:get_state() then
        local fury = local_player:get_power(enums.power_type.FURY)
        local max_fury = local_player:get_max_power(enums.power_type.FURY)
        local fury_pct = fury / max_fury
        
        local fury_color = color.blue()
        if fury >= 80 then
            fury_color = color.red()
        elseif fury >= 60 then
            fury_color = color.yellow()
        end
        
        plugin_helper:draw_text_character_center(
            string.format("Fury: %d/%d (%.0f%%)", fury, max_fury, fury_pct * 100),
            fury_color,
            -50
        )
    end
end

-- Menu render function
local function render_menu()
    menu_elements.main_tree:render(plugin_data.title, function()
        menu_elements.enable_script:render("Enable Demon Hunter PvP", "Enable the PvP rotation script")
        
        if not menu_elements.enable_script:get_state() then
            return
        end
        
        menu_elements.keybinds_tree:render("Keybinds", function()
            menu_elements.enable_toggle:render("Enable Script Toggle", "Toggle the script on/off")
        end)
        
        menu_elements.settings_tree:render("PvP Settings", function()
            menu_elements.auto_interrupt:render("Auto Interrupt", "Automatically interrupt enemy casts")
            menu_elements.auto_defensives:render("Auto Defensives", "Automatically use defensive abilities")
            menu_elements.auto_mobility:render("Auto Mobility", "Automatically use mobility spells")
            menu_elements.auto_cc:render("Auto CC", "Automatically use crowd control")
            
            menu_elements.auto_burst:render("Auto Burst", "Automatically use burst cooldowns")
            menu_elements.meta_health_threshold:render("Meta Health Threshold", "Use Metamorphosis when target below this health %")
            menu_elements.eye_beam_enemies:render("Eye Beam Min Enemies", "Minimum enemies for Eye Beam")
            
            menu_elements.blur_health_threshold:render("Blur Health Threshold", "Use Blur when below this health %")
            menu_elements.netherwalk_health_threshold:render("Netherwalk Health Threshold", "Use Netherwalk when below this health %")
        end)
        
        menu_elements.draw_plugin_state:render("Draw Plugin State", "Show plugin status on screen")
        menu_elements.draw_fury_bar:render("Draw Fury Bar", "Show fury information on screen")
        menu_elements.ts_override:render("Override Target Selector", "Use optimized target selector settings")
    end)
end

-- Control panel function
local function on_control_panel_render()
    local control_panel_elements = {}
    
    control_panel_helper:insert_toggle(control_panel_elements, {
        name = "[DH PvP] Enable (" .. key_helper:get_key_name(menu_elements.enable_toggle:get_key_code()) .. ")",
        keybind = menu_elements.enable_toggle
    })
    
    return control_panel_elements
end

-- Register callbacks
core.register_on_update_callback(on_update)
core.register_on_render_callback(on_render)
core.register_on_render_menu_callback(render_menu)
core.register_on_render_control_panel_callback(on_control_panel_render)

core.log("Demon Hunter PvP Plugin loaded successfully!")