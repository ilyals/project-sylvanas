-- Demon Hunter PvP Plugin: Header

local plugin = {}
local plugin_data = require("plugin_data")

plugin["name"] = plugin_data.name
plugin["version"] = plugin_data.version
plugin["author"] = plugin_data.author
plugin["load"] = true

-- Check if local player exists before loading the script
local local_player = core.object_manager.get_local_player()
if not local_player then
    plugin["load"] = false
    return plugin
end

---@type enums
local enums = require("common/enums")
local player_class = local_player:get_class()

-- Only load for Demon Hunter class
local is_valid_class = player_class == enums.class_id.DEMONHUNTER

if not is_valid_class then
    plugin["load"] = false
    return plugin
end

-- Only load for Havoc specialization (PvP focused)
local player_spec_id = core.spell_book.get_specialization_id()
local havoc_dh = enums.class_spec_id.get_spec_id_from_enum(enums.class_spec_id.spec_enum.HAVOC_DEMON_HUNTER)

if player_spec_id ~= havoc_dh then
    plugin["load"] = false
    return plugin
end

return plugin