-- Outside of modmain, we are in GLOBAL environment.
local DEADZONE = 0.3
local OFFSET_SPEED = 0.25
local MIN_SPEED = 0.025
local MAX_SPEED = 1

local _M = {}

local InputMeta = getmetatable(TheInput).__index
local OnControl = InputMeta.OnControl
local IsControlPressed = InputMeta.IsControlPressed

local InventoryControls = {
    [CONTROL_INVENTORY_LEFT] = true,
    [CONTROL_INVENTORY_RIGHT] = true,
    [CONTROL_INVENTORY_UP] = true,
    [CONTROL_INVENTORY_DOWN] = true,
}

local function IsInventoryControl(control)
    return InventoryControls[control]
end

local function GetPlayerController()
    return ThePlayer and ThePlayer.components.playercontroller
end


local function IsPlacerEnabled()
    local controller = GetPlayerController()
    return controller and (controller.placer or (controller.deploy_mode and controller.deployplacer))
end

InputMeta.IsControlPressed = function(self, control, e, ...)
    if e then
        return IsControlPressed(self, control, e, ...)
    end
    if IsInventoryControl(control) and IsPlacerEnabled() then
        return false
    end
    return IsControlPressed(self, control, e, ...)
end

InputMeta.OnControl = function(self, control, ...)
    if IsPlacerEnabled() and IsInventoryControl(control) then
        return
    end
    OnControl(self, control, ...)
end


function _M.SetupFollower(placer)
    if not TheInput:ControllerAttached() then
        return
    end

    local follower = CreateEntity() -- follower entity follows player position.
    follower.entity:AddTransform()
    follower:AddTag("FX")
    follower:AddTag("CLASSIFIED")
    follower.entity:SetCanSleep(false)

    placer.controller_offset = Vector3(placer.offset,0,0)

    follower:AddChild(placer.inst)
    placer.follower = follower
    placer.inst.Transform:SetPosition(placer.offset,0,0)
end


local function GetContorllerInputPosition(placer)
    return Vector3(ThePlayer.Transform:GetWorldPosition()) + placer.controller_offset
end

local function GetPlacerAlignedPosition(placer, pos, snapFn)
    if placer.snap_to_tile then
        return Vector3(TheWorld.Map:GetTileCenterPoint(pos:Get()))
    end

    if placer.snap_to_meters then
        return Vector3(math.floor(pos.x) + .5, 0, math.floor(pos.z) + .5)
    end

    if placer.onground then
        return snapFn(placer, pos)
    end

    return snapFn(placer, pos)
end

local function UpdateControllerOffset(placer, dt)
    local xdir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
    local ydir = TheInput:GetAnalogControlValue(CONTROL_INVENTORY_UP) - TheInput:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)

    if math.abs(xdir) > DEADZONE or math.abs(ydir) > DEADZONE then
        local offset = placer.controller_offset
        local camera = TheCamera or GetCamera()
        local speed_mult = placer.speed_mult or MIN_SPEED
        local dir = (camera:GetRightVec() * xdir - camera:GetDownVec() * ydir) * speed_mult
        --dir = dir:GetNormalized()
        if not placer.snap_to_meters then
            placer.controller_offset = offset+dir
        elseif GetTime() - (placer.meters_move_time or 0) > 0.1 then
            dir = dir:GetNormalized()
            if math.abs(dir.x) > math.abs(dir.z) then
                placer.controller_offset.x = placer.controller_offset.x + dir.x
            else
                placer.controller_offset.z = placer.controller_offset.z + dir.z
            end
            placer.meters_move_time = GetTime()
        end
        if placer.speed_mult > MAX_SPEED then
            placer.speed_mult = MAX_SPEED
        else
            placer.speed_mult = placer.speed_mult + (placer.speed_mult*OFFSET_SPEED*dt)
        end
    else -- reset speed
        placer.speed_mult = MIN_SPEED
    end
end

-- Update the placer follower position to player's
local function UpdateFollowerPosition(placer)
    placer.follower.Transform:SetPosition(ThePlayer.Transform:GetWorldPosition())
end

local function UpdatePlacerLocalPosition(placer, snapFn)
    local pos = GetContorllerInputPosition(placer)
    local aligned = GetPlacerAlignedPosition(placer, pos, snapFn)
    local followerPos = Vector3(placer.follower.Transform:GetWorldPosition())
    local relative = aligned - followerPos

    placer.inst.Transform:SetPosition(relative:Get())
end

function _M.Update(placer, dt, snapFn)
    if not TheInput:ControllerAttached() then
        return
    end

    UpdateFollowerPosition(placer)

    UpdateControllerOffset(placer, dt)

    UpdatePlacerLocalPosition(placer, snapFn)
end

return _M
