//=============================================================================
//
// lua\Bot.lua
//
// Implementation of Natural Selection 2 bot commands and event hooks
//
// Copyright 2011 Colin Graf (colin.graf@sovereign-labs.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//=============================================================================

class 'Bot'

function Bot:GetPlayer()
    return self.client:GetControllingPlayer()
end

//=============================================================================

local botBots = { }
local botMaxCount = 0

function Bot_OnConsoleSetBots(client, countParam)

    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end

    // set max bot count
    if countParam then
        botMaxCount = math.min(10, math.max(0, tonumber(countParam)))
    end
    
    // compute new bot count
    local totalPlayerCount = Shared.GetEntitiesWithClassname("Player"):GetSize()
    local normalPlayerCount = totalPlayerCount - table.maxn(botBots)
    local botCount = math.min(math.max(botMaxCount + 1 - normalPlayerCount, 0), botMaxCount)
    
    // add more bots
    while table.maxn(botBots) < botCount do
    
        local bot = BotJeffco()
        bot:Initialize()
        bot.client = Server.AddVirtualClient()
        table.insert(botBots, bot)
   
    end
    
    // remove bots
    while table.maxn(botBots) > botCount do

        // find larger team
        local largerTeam
        local rules = GetGamerules()
        local playersTeam1 = rules:GetTeam(kTeam1Index):GetNumPlayers()
        local playersTeam2 = rules:GetTeam(kTeam2Index):GetNumPlayers()
        if playersTeam1 > playersTeam2 then
            largerTeam = kTeam1Index
        elseif playersTeam2 > playersTeam1 then
            largerTeam = kTeam2Index
        else
            largerTeam = ConditionalValue(math.random() < 0.5, kTeam1Index, kTeam2Index)
        end
    
        // find bot from larger team
        local botToRemove = 1
        for i, bot in ipairs(botBots) do
            local player = bot.client:GetControllingPlayer()
            if player:GetTeamNumber() == largerTeam then
                botToRemove = i
                break
            end
        end
        
        // remove bot
        local bot = botBots[botToRemove]
        Server.DisconnectClient(bot.client)
        bot.client = nil
        table.remove(botBots, botToRemove)
    end

end

function Bot_OnConsoleAddBots(client, countParam)

    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end
    
    // update bot count
    local count = 1
    if countParam then
        count = math.max(1, tonumber(countParam))
    end    
    Bot_OnConsoleSetBots(client, botMaxCount + count)
    
end

function Bot_OnConsoleRemoveBots(client, countParam)
    
    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end
    
    // update bot count
    local count = 1
    if countParam then
        count = math.max(1, tonumber(countParam))
    end    
    Bot_OnConsoleSetBots(client, botMaxCount - count)
    
end

function Bot_OnVirtualClientMove(client)

    for _, bot in ipairs(botBots) do    
        if bot.client == client then
            return bot:OnMove()
        end        
    end

end

function Bot_OnVirtualClientThink(client, deltaTime)

    for _, bot in ipairs(botBots) do
        if bot.client == client then
            return bot:OnThink(deltaTime)
        end
    end

end

function Bot_OnUpdateServer()

    if math.random() < .005 then
        Bot_OnConsoleSetBots()
    end

end

Event.Hook("Console_addbot",         Bot_OnConsoleAddBots)
Event.Hook("Console_removebot",      Bot_OnConsoleRemoveBots)
Event.Hook("Console_addbots",        Bot_OnConsoleAddBots)
Event.Hook("Console_removebots",     Bot_OnConsoleRemoveBots)
Event.Hook("Console_setbots",        Bot_OnConsoleSetBots)

Event.Hook("VirtualClientThink",     Bot_OnVirtualClientThink)
Event.Hook("VirtualClientMove",      Bot_OnVirtualClientMove)

Event.Hook("UpdateServer",           Bot_OnUpdateServer)

Script.Load("lua/Bot_Jeffco.lua")
