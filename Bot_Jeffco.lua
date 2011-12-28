//=============================================================================
//
// lua\Bot_Jeffco.lua
//
// AI "bot" functions for goal setting and moving (used by Bot.lua).
//
// Created by Colin Graf (colin.graf@sovereign-labs.com)
// Based on Bot_Player.lua by Charlie Cleveland (charlie@unknownworlds.com)
// Copyright (c) 2011, Unknown Worlds Entertainment, Inc.
//
//=============================================================================

Script.Load("lua/Bot.lua")

local kBotNames = {
    "Bennet (bot)", "Petrelli (bot)", "Nakamura (bot)", "Suresh (bot)", "Masahashi (bot)", "Sylar (bot)", "Parkman (bot)",
    "Sanders (bot)"
}

class 'BotJeffco' (Bot)

function BotJeffco:UpdateName()

    // Set name after a bit of time to simulate real players
    if math.random() < .01 then

        local player = self:GetPlayer()
        local name = player:GetName()
        if name and string.find(string.lower(name), string.lower(kDefaultPlayerName)) ~= nil then
    
            local numNames = table.maxn(kBotNames)
            local index = Clamp(math.ceil(math.random() * numNames), 1, numNames)
            OnCommandSetName(self.client, kBotNames[index])
            
        end
        
    end
    
end

function BotJeffco:GetOrderLocation()
    local player = self:GetPlayer()
    local order = player:GetCurrentOrder()
    if order ~= nil then
        local orderType = order:GetType()
        local orderTarget = Shared.GetEntity(order:GetParam())
        if (orderType == kTechId.Attack or orderType == kTechId.Construct) and orderTarget ~= nil then
            self.orderLocation = orderTarget:GetEngagementPoint()
        else 
            self.orderLocation = order:GetLocation()
        end
    end
    return self.orderLocation
end

function BotJeffco:MoveToPoint(toPoint)

    local player = self:GetPlayer()
    
    //if not self:IsPathValid(player:GetEyePos(), toPoint) then
        if self:BuildPath(player:GetEyePos(), toPoint) then
          local points = self:GetPoints()
          if points ~= nil then
            toPoint = points[1]
          end
          if #points > 1 and (player:GetEyePos() - toPoint):GetLengthSquared() < 4 then
            toPoint = points[2]
          end
        end
    //end
    
    // Fill in move to get to specified point
    local diff = toPoint - player:GetEyePos()
    local direction = GetNormalizedVector(diff)
        
    // Look at target (needed for moving and attacking)
    self.move.yaw   = GetYawFromVector(direction) - player.baseYaw
    self.move.pitch = GetPitchFromVector(direction) - player.basePitch
    
    // walk forwards
    self.move.move.z = 1
end

function BotJeffco:LookAtPoint(toPoint)

    local player = self:GetPlayer()

    // Fill in move to get to specified point
    local diff = toPoint - player:GetEyePos()
    local direction = GetNormalizedVector(diff)
        
    // Look at target (needed for moving and attacking)
    self.move.yaw   = GetYawFromVector(direction) - player.baseYaw
    self.move.pitch = GetPitchFromVector(direction) - player.basePitch

end

/**
 * Responsible for generating the "input" for the bot. This is equivalent to
 * what a client sends across the network.
 */
function BotJeffco:GenerateMove()

    local player = self:GetPlayer()
    local move = Move()
    
    // keep the current yaw/pitch as default
    move.yaw = player:GetAngles().yaw - player.baseYaw
    move.pitch = player:GetAngles().pitch - player.basePitch
    
    // use the state machine
    self.move = move;
    if self.currentState == nil then
      self.currentState = self.InitialState
    end
    self.currentState = self.currentState(self) // pass #1
    //self.currentState = self.currentState(self) // pass #2
    
    return self.move
end

function BotJeffco:OnThink()

    Bot.OnThink(self)
        
    self:UpdateName()
    
end

//=============================================================================
// States

function BotJeffco:InitialState()

  // attack?
  // TODO

  // move?
  local orderLocation = self:GetOrderLocation()
  if orderLocation ~= nil and self.lastOrderLocation ~= orderLocation then
    return self.MoveState
  end
  
  // construct?
  local player = self:GetPlayer()
  local order = player:GetCurrentOrder()
  if order ~= nil and order:GetType() == kTechId.Construct and Shared.GetEntity(order:GetParam()) ~= nil then
    return self.ConstructState
  end

  // stay
  return self.InitialState
end

function BotJeffco:MoveState()

  // move?
  local orderLocation = self:GetOrderLocation()
  if orderLocation == nil then
    return self.InitialState
  end
  
  // move to target
  self:MoveToPoint(orderLocation)
  
  // target reached?
  local player = self:GetPlayer()
  if (player:GetEyePos() - orderLocation):GetLengthSquared() < 4 then
    self.lastOrderLocation = orderLocation
    return self.InitialState
  end

  return self.MoveState
end

function BotJeffco:ConstructState()

  // construct?
  local player = self:GetPlayer()
  local order = player:GetCurrentOrder()
  if order == nil or order:GetType() ~= kTechId.Construct then
    return self.InitialState
  end  
  local buildObject = Shared.GetEntity(order:GetParam())
  if buildObject == nil then
    return self.InitialState
  end
  
   // look at build object
  self:LookAtPoint(buildObject:GetEngagementPoint())

  // construct!
  self.move.commands = bit.bor(self.move.commands, Move.Use)
  
  return self.ConstructState
end
