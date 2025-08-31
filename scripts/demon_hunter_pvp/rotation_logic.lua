-- Demon Hunter PvP Plugin: Rotation Logic

---@type enums
local enums = require("common/enums")

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

---@type pvp_helper
local pvp_helper = require("common/utility/pvp_helper")

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

local spells = require("spells")

local RotationLogic = {}

-- Timing variables to prevent spam
local last_cast_times = {}

local function can_cast_spell(spell_id, local_player, target, min_interval)
    min_interval = min_interval or 0.2
    local current_time = core.time()
    
    if last_cast_times[spell_id] and (current_time - last_cast_times[spell_id]) < min_interval then
        return false
    end
    
    return spell_helper:is_spell_castable(spell_id, local_player, target, false, false)
end

local function cast_spell(spell_id, target, priority, message)
    local current_time = core.time()
    last_cast_times[spell_id] = current_time
    spell_queue:queue_spell_target(spell_id, target, priority, message)
    return true
end

-- Check if we should use AoE abilities
function RotationLogic:should_use_aoe(target)
    local enemies_around = unit_helper:get_enemy_list_around(target:get_position(), 8.0)
    return #enemies_around >= 2
end

-- Get current fury
function RotationLogic:get_fury(local_player)
    return local_player:get_power(enums.power_type.FURY)
end

-- Check if in metamorphosis
function RotationLogic:is_in_metamorphosis(local_player)
    local meta_data = buff_manager:get_buff_data(local_player, enums.buff_db.METAMORPHOSIS)
    return meta_data.is_active
end

-- Defensive logic
function RotationLogic:handle_defensives(local_player, target)
    local health_pct = unit_helper:get_health_percentage(local_player)
    
    -- Emergency defensives
    if health_pct < 0.3 then
        if can_cast_spell(spells.netherwalk.id, local_player, local_player) then
            return cast_spell(spells.netherwalk.id, local_player, 10, "Emergency Netherwalk")
        end
        
        if can_cast_spell(spells.blur.id, local_player, local_player) then
            return cast_spell(spells.blur.id, local_player, 9, "Emergency Blur")
        end
    end
    
    -- Moderate health defensives
    if health_pct < 0.6 then
        if can_cast_spell(spells.darkness.id, local_player, local_player) then
            return cast_spell(spells.darkness.id, local_player, 8, "Darkness")
        end
    end
    
    return false
end

-- Interrupt logic
function RotationLogic:handle_interrupts(local_player, target)
    if not target:is_casting_spell() then
        return false
    end
    
    if not target:is_active_spell_interruptable() then
        return false
    end
    
    local distance = local_player:get_position():dist_to(target:get_position())
    
    -- Disrupt (melee range interrupt)
    if distance <= 8 and can_cast_spell(spells.disrupt.id, local_player, target) then
        return cast_spell(spells.disrupt.id, target, 15, "Interrupt with Disrupt")
    end
    
    -- Consume Magic (ranged dispel/interrupt)
    if distance <= 20 and can_cast_spell(spells.consume_magic.id, local_player, target) then
        return cast_spell(spells.consume_magic.id, target, 14, "Interrupt with Consume Magic")
    end
    
    return false
end

-- Burst damage logic
function RotationLogic:handle_burst(local_player, target)
    local fury = self:get_fury(local_player)
    local in_meta = self:is_in_metamorphosis(local_player)
    
    -- Use metamorphosis for burst
    if not in_meta and can_cast_spell(spells.metamorphosis.id, local_player, local_player) then
        local target_health = unit_helper:get_health_percentage(target)
        local has_burst = pvp_helper:has_burst_active(target)
        
        -- Use meta when target is low or we need to counter their burst
        if target_health < 0.4 or has_burst then
            return cast_spell(spells.metamorphosis.id, local_player, 12, "Metamorphosis Burst")
        end
    end
    
    -- Eye Beam for high damage and fury generation
    if fury >= 30 and can_cast_spell(spells.eye_beam.id, local_player, target) then
        if self:should_use_aoe(target) or in_meta then
            return cast_spell(spells.eye_beam.id, target, 11, "Eye Beam")
        end
    end
    
    -- Essence Break for burst setup
    if can_cast_spell(spells.essence_break.id, local_player, target) then
        return cast_spell(spells.essence_break.id, target, 10, "Essence Break")
    end
    
    return false
end

-- Core rotation logic
function RotationLogic:handle_rotation(local_player, target)
    local fury = self:get_fury(local_player)
    local in_meta = self:is_in_metamorphosis(local_player)
    local is_aoe = self:should_use_aoe(target)
    
    -- High priority: Spend fury when capped or in meta
    if fury >= 80 or in_meta then
        -- Use Death Sweep in meta for AoE
        if in_meta and is_aoe and can_cast_spell(spells.death_sweep.id, local_player, target) then
            return cast_spell(spells.death_sweep.id, target, 8, "Death Sweep (Meta AoE)")
        end
        
        -- Use Annihilation in meta
        if in_meta and can_cast_spell(spells.annihilation.id, local_player, target) then
            return cast_spell(spells.annihilation.id, target, 7, "Annihilation (Meta)")
        end
        
        -- Use Blade Dance for AoE
        if is_aoe and can_cast_spell(spells.blade_dance.id, local_player, target) then
            return cast_spell(spells.blade_dance.id, target, 6, "Blade Dance (AoE)")
        end
        
        -- Use Chaos Strike for single target
        if can_cast_spell(spells.chaos_strike.id, local_player, target) then
            return cast_spell(spells.chaos_strike.id, target, 5, "Chaos Strike")
        end
    end
    
    -- Medium priority: Fury generators
    if fury < 60 then
        -- Felblade for gap closer and fury
        if can_cast_spell(spells.felblade.id, local_player, target) then
            local distance = local_player:get_position():dist_to(target:get_position())
            if distance > 8 and distance <= 15 then
                return cast_spell(spells.felblade.id, target, 4, "Felblade (Gap Closer)")
            end
        end
        
        -- Demon's Bite for fury generation
        if can_cast_spell(spells.demons_bite.id, local_player, target) then
            return cast_spell(spells.demons_bite.id, target, 3, "Demon's Bite")
        end
    end
    
    -- Low priority: Utility abilities
    -- Throw Glaive for ranged damage when out of melee
    local distance = local_player:get_position():dist_to(target:get_position())
    if distance > 8 and can_cast_spell(spells.throw_glaive.id, local_player, target) then
        return cast_spell(spells.throw_glaive.id, target, 2, "Throw Glaive (Ranged)")
    end
    
    return false
end

-- Mobility and positioning
function RotationLogic:handle_mobility(local_player, target)
    local distance = local_player:get_position():dist_to(target:get_position())
    local player_health = unit_helper:get_health_percentage(local_player)
    
    -- Vengeful Retreat for kiting when low health
    if player_health < 0.5 and distance < 8 then
        if can_cast_spell(spells.vengeful_retreat.id, local_player, local_player) then
            return cast_spell(spells.vengeful_retreat.id, local_player, 13, "Vengeful Retreat (Kite)")
        end
    end
    
    -- Fel Rush for gap closing
    if distance > 12 and distance <= 20 then
        if can_cast_spell(spells.fel_rush.id, local_player, target) then
            return cast_spell(spells.fel_rush.id, target, 6, "Fel Rush (Gap Close)")
        end
    end
    
    return false
end

-- CC and utility
function RotationLogic:handle_utility(local_player, target)
    -- Imprison for CC (when target is not immune)
    if not pvp_helper:is_cc_immune(target, pvp_helper.cc_flags.INCAPACITATE) then
        if can_cast_spell(spells.imprison.id, local_player, target) then
            local target_health = unit_helper:get_health_percentage(target)
            -- Use imprison strategically - when target is healing or casting important spells
            if target:is_casting_spell() or target_health < 0.3 then
                return cast_spell(spells.imprison.id, target, 16, "Imprison CC")
            end
        end
    end
    
    return false
end

-- Main execution function
function RotationLogic:execute(local_player, target)
    -- Priority order for PvP:
    -- 1. Interrupts (highest priority)
    if self:handle_interrupts(local_player, target) then return true end
    
    -- 2. Defensives when needed
    if self:handle_defensives(local_player, target) then return true end
    
    -- 3. CC and utility
    if self:handle_utility(local_player, target) then return true end
    
    -- 4. Burst damage
    if self:handle_burst(local_player, target) then return true end
    
    -- 5. Mobility
    if self:handle_mobility(local_player, target) then return true end
    
    -- 6. Core rotation
    if self:handle_rotation(local_player, target) then return true end
    
    return false
end

return RotationLogic