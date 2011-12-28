//=============================================================================
//
// lua\Bot_Jeffco.lua
//
// A simple bot implementation for Natural Selection 2
//
// Version 0.2
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

Script.Load("lua/Bot.lua")

class 'BotJeffco' (Bot)

BotJeffco.kBotNames = {
    "Bennet (bot)", "Petrelli (bot)", "Nakamura (bot)", "Suresh (bot)", "Masahashi (bot)", "Sylar (bot)", "Parkman (bot)",
    "Sanders (bot)"
}
BotJeffco.kDebugMode = false
BotJeffco.kRange = 30

function BotJeffco:GetOrderLocation()

    local player = self:GetPlayer()
    local order = player:GetCurrentOrder()
    
    if order then
        local orderType = order:GetType()
        local orderTarget = Shared.GetEntity(order:GetParam())
        if (orderType == kTechId.Attack or orderType == kTechId.Construct) and orderTarget then
            self.orderLocation = orderTarget:GetEngagementPoint()
        else 
            self.orderLocation = order:GetLocation()
        end
    end
    
    return self.orderLocation
end

function BotJeffco:GetOrderTarget(type)

    local player = self:GetPlayer()
    local order = player:GetCurrentOrder()
    
    if order and order:GetType() == type then
      return Shared.GetEntity(order:GetParam())
    end

end

function BotJeffco:GetAttackTarget()

    local player = self:GetPlayer()

    if not player.targetSelector then
        if player:isa("Marine") then
            player.targetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kMarineStaticTargets, kMarineMobileTargets },
                { /* PitchTargetFilter(self,  -Sentry.kMaxPitch, Sentry.kMaxPitch), */ CloakTargetFilter(), CamouflageTargetFilter() })
        end
        if player:isa("Alien") then
            player.targetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kAlienStaticTargets, kAlienMobileTargets },
                { /* PitchTargetFilter(self,  -Sentry.kMaxPitch, Sentry.kMaxPitch), CloakTargetFilter(), CamouflageTargetFilter() */ })
        end
    end
    
    if player.targetSelector then
        if self.lastTargetCachePos == nil or (player:GetEyePos() - self.lastTargetCachePos):GetLengthSquared() > 4 then
            player.targetSelector:AttackerMoved()
            self.lastTargetCachePos = player:GetEyePos()
        end
        local target = player.targetSelector:AcquireTarget()
        if target then
            return target
        end
    end
    
    return self:GetOrderTarget(kTechId.Attack)
end

function BotJeffco:LookAtPoint(toPoint, direct)

    local player = self:GetPlayer()

    // compute direction to target
    local diff = toPoint - player:GetEyePos()
    local direction = GetNormalizedVector(diff)
    
    // look at target
    if direct then
        self.move.yaw = GetYawFromVector(direction) - player.baseYaw
        self.move.pitch = GetPitchFromVector(direction) - player.basePitch
    else
        self.move.yaw = SlerpRadians(self.move.yaw, GetYawFromVector(direction) - player.baseYaw, .4)
        self.move.pitch = SlerpRadians(self.move.pitch, GetPitchFromVector(direction) - player.basePitch, .4)
    end
    
end

function BotJeffco:MoveToPoint(toPoint)

    local player = self:GetPlayer()
    
    // use pathfinder
    if self:BuildPath(player:GetEyePos(), toPoint) then
        local points = self:GetPoints()
        if points then
            toPoint = points[1]
        end
        if table.maxn(points) > 1 and (player:GetEyePos() - toPoint):GetLengthSquared() < 4 then
            toPoint = points[2]
        end
    end
    
    // look at target
    self:LookAtPoint(toPoint)
    
    // walk forwards
    self.move.move.z = 1
end

function BotJeffco:StateTrace(name)

  if BotJeffco.kDebugMode and self.stateName ~= name then
    Print("%s", name)
    self.stateName = name
  end

end

//=============================================================================

function BotJeffco:GenerateMove()

    local player = self:GetPlayer()
    local move = Move()
    
    // keep the current yaw/pitch as default
    move.yaw = player:GetAngles().yaw - player.baseYaw
    move.pitch = player:GetAngles().pitch - player.basePitch
    
    // use a state machine to generate a move
    local currentTime = Shared.GetTime()
    self.move = move
    //self.state = nil
    if self.state == nil then
      self.state = self.InitialState
      self.stateEnterTime = currentTime
    end
    self.stateTime = currentTime - self.stateEnterTime
    local newState = self.state(self)
    if newState ~= self.state then
      self.stateEnterTime = currentTime
    end
    self.state = newState
    
    return self.move
end

function BotJeffco:OnThink()

    Bot.OnThink(self)
    
end

//=============================================================================
// States

function BotJeffco:InitialState()

    self:StateTrace("initial")

    // wait a few seconds, set name and start idling
    if self.stateTime > 6 then
  
        local player = self:GetPlayer()
        local name = player:GetName()
        if name and string.find(string.lower(name), string.lower(kDefaultPlayerName)) then
    
            local numNames = table.maxn(BotJeffco.kBotNames)
            local index = Clamp(math.ceil(math.random() * numNames), 1, numNames)
            OnCommandSetName(self.client, BotJeffco.kBotNames[index])

        end
        
        return self.IdleState
   
    end
  
    return self.InitialState
end

function BotJeffco:IdleState()
  
    self:StateTrace("idle")
     
    // respawing?
    local player = self:GetPlayer()
    if player:isa("AlienSpectator") then
       return self.HatchState
    end
        
    // attack?
    if self:GetAttackTarget() then
        return self.AttackState
    end
    
    // construct order?
    if self:GetOrderTarget(kTechId.Construct) then
        return self.ConstructState
    end

    // move order?
    local orderLocation = self:GetOrderLocation()
    if orderLocation and (player:GetEyePos() - orderLocation):GetLengthSquared() > 4 then
        return self.MoveState
    end
    
    // walk around
    if math.random() < .05 then
        return self.RandomWalkState
    end

    // look around
    if math.random() < .1 then
        return self.RandomLookState
    end
    
    // stay
    return self.IdleState
end

function BotJeffco:RandomLookState()

    self:StateTrace("random look")
    
    // attack?
    if self:GetAttackTarget() then
        return self.AttackState
    end

    if self.randomLookTarget == nil then
        local player = self:GetPlayer()
        self.randomLookTarget = player:GetEyePos()
        self.randomLookTarget.x = self.randomLookTarget.x + math.random(-50, 50)
        self.randomLookTarget.z = self.randomLookTarget.z + math.random(-50, 50)
    end

    self:LookAtPoint(self.randomLookTarget)
    
    if self.lastYaw then
        if (math.abs(self.move.yaw - self.lastYaw) < .05 and math.abs(self.move.pitch - self.lastPitch) < .05) or self.stateTime > 10 then
            self.randomLookTarget = nil
            return self.IdleState
        end
    end    
    self.lastYaw = self.move.yaw
    self.lastPitch = self.move.pitch

    return self.RandomLookState
end

function BotJeffco:RandomWalkState()

    self:StateTrace("random walk")
    
    // attack?
    if self:GetAttackTarget() then
        return self.AttackState
    end

    local player = self:GetPlayer()
    if self.randomWalkTarget == nil then
        self.randomWalkTarget = player:GetEyePos()
        self.randomWalkTarget.x = self.randomWalkTarget.x + math.random(-8, 8)
        self.randomWalkTarget.z = self.randomWalkTarget.z + math.random(-8, 8)
    end

    self:MoveToPoint(self.randomWalkTarget)
    
    if (player:GetEyePos() - self.randomWalkTarget):GetLengthSquared() < 4 or self.stateTime > 4 then
        self.randomWalkTarget = nil
        return self.IdleState
    end
  
    return self.RandomWalkState
end

function BotJeffco:HatchState()

    self:StateTrace("hatch")

    local player = self:GetPlayer()
    if not player:isa("AlienSpectator") then
       return self.IdleState
    end

    self.move.commands = Move.PrimaryAttack
    
    return self.HatchState
end

function BotJeffco:MoveState()

    self:StateTrace("move")

    // move?
    local orderLocation = self:GetOrderLocation()
    if orderLocation == nil then
        return self.IdleState
    end
  
    // move to target
    self:MoveToPoint(orderLocation)
  
    // target reached?
    local player = self:GetPlayer()
    if (player:GetEyePos() - orderLocation):GetLengthSquared() < 4 then
        return self.IdleState
    end

    return self.MoveState
end

function BotJeffco:ConstructState()

    self:StateTrace("construct")
    
    // construct?
    local constructTarget = self:GetOrderTarget(kTechId.Construct)
    if constructTarget == nil then
        return self.IdleState
    end

    // is target reachable?    
    local player = self:GetPlayer()
    local engagementPoint = constructTarget:GetEngagementPoint()
    if (player:GetEyePos() - engagementPoint):GetLengthSquared() > 4 then
        self:MoveToPoint(engagementPoint)
    end
  
    // look at build object
    self:LookAtPoint(constructTarget:GetEngagementPoint(), true)

    // construct!
    self.move.commands = bit.bor(self.move.commands, Move.Use)
  
    return self.ConstructState
end

function BotJeffco:AttackState()

    self:StateTrace("attack")

    // attack?
    local attackTarget = self:GetAttackTarget()
    if attackTarget == nil then
        return self.IdleState
    end
  
    // choose weapon
    local player = self:GetPlayer()
    local activeWeapon = player:GetActiveWeapon()
    if activeWeapon then
        local outOfAmmo = player:isa("Marine") and activeWeapon:isa("ClipWeapon") and activeWeapon:GetAmmo() == 0
        if self.outOfAmmo == nil then
          self.outOfAmmo = 0
        end
        if outOfAmmo then
            self.outOfAmmo = self.outOfAmmo + 1
        end
        if (attackTarget:isa("Structure") and not activeWeapon:isa("Axe")) then
            self.move.commands = bit.bor(self.move.commands, Move.Weapon3)
        elseif attackTarget:isa("Player") and not activeWeapon:isa("Rifle") and self.outOfAmmo < 2 and not outOfAmmo then
            self.move.commands = bit.bor(self.move.commands, Move.Weapon1)
        elseif outOfAmmo then
            self.move.commands = bit.bor(self.move.commands, Move.NextWeapon)
        end        
    end
    
    // move to axe a target?
    local melee = false
    if activeWeapon and activeWeapon:isa("Axe") then
        melee = true
        local engagementPoint = attackTarget:GetEngagementPoint()
        local allowedDistance = 4
        if attackTarget:isa("Hive") then
            allowedDistance = 10
        end        
        if (player:GetEyePos() - engagementPoint):GetLengthSquared() > allowedDistance then
            self:MoveToPoint(engagementPoint)
            return self.AttackState
        elseif not attackTarget:isa("Hive") then
            self.move.commands = bit.bor(self.move.commands, Move.Crouch)
        end
    end
    
    // as alien move to target
    if player:isa("Alien") then
        melee = true
        local engagementPoint = attackTarget:GetEngagementPoint()
        if (player:GetEyePos() - engagementPoint):GetLengthSquared() > 4 then
            self:MoveToPoint(engagementPoint)
            return self.AttackState
        end
    end

    // look at attack target
    self:LookAtPoint(attackTarget:GetEngagementPoint(), melee)

    // attack!
    self.move.commands = bit.bor(self.move.commands, Move.PrimaryAttack)

    return self.AttackState
end
