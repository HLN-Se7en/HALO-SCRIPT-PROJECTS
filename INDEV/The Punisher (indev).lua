--[[
--=====================================================================================================--
Script Name: The Punisher (v1.0), for SAPP (PC & CE)

Description: This script will punish players for certain actions (i.e, betrayals)

Copyright (c) 2019, Jericho Crosby <jericho.crosby227@gmail.com>
* Notice: You can use this document subject to the following conditions:
https://github.com/Chalwk77/Halo-Scripts-Phasor-V2-/blob/master/LICENSE

* Written by Jericho Crosby (Chalwk)
--=====================================================================================================--
]]--

api_version = "1.12.0.0"

local punish = {}
local betray_count
local betray_warnings, teamshoot_warnings = { }, { }
local gsub = string.gsub

local globals = nil

function punish.Init()
    -- Configuration [starts] -----------------------------------------------------
    
    punish.betrayals = {
        enabled = true,
        
        -- Valid actions:
        actions = { -- Only ONE action can be enabled!
            ["kill"] = {
                use = true,
                warnings = 2,
                respawn_time = 10,
                message = '%offender_name%, you were killed for betraying %betrayals% times!',
            },
            ["kick"] = {
                use = false,
                warnings = 2,
                message = '%offender_name% was kicked for betraying %betrayals% times!',
            },
            ["crash"] = {
                use = false,
                warnings = 5,
                message = "%offender_name%'s game client was crashed (by server) for betraying!",
            },
        }
    }
    
    punish.teamshooting = {
        enabled = true,
        
        -- Valid actions:
        actions = {
            ["warn"] = {
                use = false,
                warnings = 5,
                message = "%offender_name%, please don't team-shoot or you will be punished!",
            },
        }
    }
    -- Configuration [ends] -----------------------------------------------------
end

function OnScriptLoad()
    
    punish.Init()
    
    -- Register needed Event Callbacks: 
    
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    
    if (punish.betrayals.enabled) or (punish.teamshooting.enabled) then
        register_callback(cb['EVENT_DIE'], "OnPlayerDeath")
        register_callback(cb['EVENT_JOIN'], "OnPlayerConnect")
        register_callback(cb['EVENT_LEAVE'], "OnPlayerDisconnect")
    end
    
    if (get_var(0, "$gt") ~= "n/a") then
        punish.Reset()
    end
    
    local gp = sig_scan("8B3C85????????3BF9741FE8????????8B8E2C0200008B4610") + 3
    if (gp == 3) then
        return
    end
    globals = read_dword(gp)
end

function OnScriptUnload()
    -- Not Used
end

function OnGameStart()
    red_flag, blue_flag = read_dword(globals + 0x8), read_dword(globals + 0xC)
end

function OnPlayerConnect(PlayerIndex)
    betray_warnings[PlayerIndex] = punish.betrayals.warnings
    teamshoot_warnings[PlayerIndex] = punish.teamshooting.warnings
end

function OnPlayerDisconnect(PlayerIndex)
    betray_warnings[PlayerIndex] = nil
    teamshoot_warnings[PlayerIndex] = nil
end

function punish.warningsReached(params)
    local params = params or nil
    
    if (params ~= nil) then
        local type = params.type
        local current_warnings = params.current_warnings
        local player = params.player
        
        if (type[player] >= current_warnings) then
            return true
        end
    end
end

function OnPlayerDeath(PlayerIndex, KillerIndex)
    
    local victim = tonumber(PlayerIndex)
    local killer = tonumber(KillerIndex)
    local name = get_var(killer, '$name')
    
    local vTeam, kTeam = get_var(victim, "$team"), get_var(killer, "$team")
    
    -- Check if the killer is a player:
    if (killer > 0) then
        
        -- Check if the victim is on the same team as the killer:
        if (kTeam == vTeam) then
        
            
            
            -- Increment betray warnings by 1:
            betray_warnings[killer] = betray_warnings[killer] + 1
                    
            local betray = punish.betrayals.actions
            
            
            local p = { }
            p.player = killer
            p.type = betray_warnings
            
            for k,v in pairs(betray) do
                
                if (k == "kill" and betray[k].use == true) then
                
                    if punish.warningsReached(p) then
                    
                        p.respawn_time = betray[k].respawn_time
                        punish.KillSilently(p)
                    
                        local msg = gsub(gsub(betray[k].message, "%%offender_name%%", name), "%%betrayals%%", betray[k].warnings)
                        say(killer, msg)
                    end
                    
                elseif (k == "kick" and betray[k].use == true) then
                    execute_command("k" .. " " .. killer .. " Betraying")
                    
                    local msg = gsub(gsub(betray[k].message, "%%offender_name%%", name), "%%betrayals%%", betray[k].warnings)
                    say_all(msg)
                    cprint(name .. " was kicked for " .. msg, 4 + 8)
                    
                elseif (k == "crash" and betray[k].use == true) then
                    
                    
                    execute_command("k" .. " " .. killer .. " Betraying")
                    
                    local msg = gsub(gsub(betray[k].message, "%%offender_name%%", name), "%%betrayals%%", betray[k].warnings)
                    say_all(msg)
                    cprint(name .. " was kicked for " .. msg, 4 + 8)
                end
            end
        end
    end
end

function punish.Reset()
    if (punish.betrayals.enabled) then
    
        -- Clear the array:
        betray_warnings = { }
        teamshoot_warnings = { }
        
        for i = 1,16 do
            if player_present(i) then
                betray_warnings[i] = punish.betrayals.warnings
                teamshoot_warnings[i] = punish.teamshooting.warnings
            end
        end
    end
end

function punish.KillSilently(params)
    local params = params or nil
    
    if (params ~= nil) then
        if ClearInventory() then
            local kma = sig_scan("8B42348A8C28D500000084C9") + 3
            local original = read_dword(kma)
            
            safe_write(true)
            write_dword(kma, 0x03EB01B1)
            safe_write(false)
            
            execute_command("kill " .. tonumber(params.player))
            safe_write(true)
            write_dword(kma, original)
            safe_write(false)
            
            write_dword(get_player(params.player) + 0x2C, tonumber(params.respawn_time) * 33)
            
            -- Deduct one death:
            local deaths = tonumber(get_var(params.player, "$deaths"))
            execute_command("deaths " .. tonumber(params.player) .. " " .. deaths - 1)
        end
    end
end

local function DestroyObject(object)
    if (object) then
        destroy_object(object)
    end
end

function punish.Crash(params)
    
    local params = params or nil
    if (params ~= nil) then
        local player_object = get_dynamic_player(params.player)
        if (player_object ~= 0) then
            local x, y, z = read_vector3d(player_object + 0x5C)
            local vehicleID = spawn_object("vehi", "vehicles\\rwarthog\\rwarthog", x, y, z)
            local vehicleObject = get_object_memory(vehicleID)
            if (vehicleObject ~= 0) then
                for j = 0, 20 do
                    enter_vehicle(vehicleID, params.player, j)
                    exit_vehicle(params.player)
                end
                DestroyObject(vehicleID)
            end
        end
    end
end

function ClearInventory(params)
    local params = params or nil
    
    if (params ~= nil) then
        local player_object = get_dynamic_player(params.player)
        if (player_object ~= 0) then
        
            -- Set grenade count to zero:
            write_word(player_object + 0x31E, 0)
            write_word(player_object + 0x31F, 0)
            
            -- Loop through player inventory and delete each weapon object:
            local weaponID = read_dword(player_object + 0x118)
            if (weaponID ~= 0) then
                for j = 0, 3 do
                    local weapon = read_dword(player_object + 0x2F8 + 4 * j)
                    if (weapon ~= red_flag) and (weapon ~= blue_flag) then
                        DestroyObject(weapon)
                    end
                end
            end
            return true
        end
    end
end
