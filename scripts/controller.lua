-- Outside of modmain, we are in GLOBAL environment.
local DEADZONE = 0.3
local OFFSET_SPEED = 0.25

local _M = {}

local CancelControllerTargetWhenPlacing = function(self, dt)
    if self.placer ~= nil or (self.deployplacer ~= nil and self.deploy_mode) then
        self.controller_target = nil
        self.controller_target_delay = 0.5
        return
    end
end

local InputMeta = getmetatable(TheInput).__index
local OnControl = InputMeta.OnControl
local IsControlPressed = InputMeta.IsControlPressed

local function isInventoryControl(ctrl)
	return ctrl == CONTROL_INVENTORY_LEFT or ctrl == CONTROL_INVENTORY_RIGHT or ctrl == CONTROL_INVENTORY_UP or ctrl == CONTROL_INVENTORY_DOWN
end

InputMeta.IsControlPressed = function(self, control, e, ...)
	if e then --not efficient, i know.
		return iscontrolpressed_old(self, control, e, ...)
	end
	local controller = ThePlayer and ThePlayer.components.playercontroller
	if isInventoryControl(control) and controller and (controller.placer or (controller.deploy_mode and controller.deployplacer)) then
		return false
    end
    return IsControlPressed(self, control, e, ...)
end

InputMeta.OnControl = function(self, control, ...)
	--70 is the mod (menu misc 3)
	local controller = ThePlayer and ThePlayer.components.playercontroller
	if controller and controller.placer and isInventoryControl(control) then
		return
    end
	OnControl(self, control, ...)
end

function _M.PostInit(self)
	self.placer_parent = CreateEntity()
	self.placer_parent.entity:AddTransform() self.placer_parent:AddTag("FX") self.placer_parent:AddTag("CLASSIFIED") self.placer_parent.entity:SetCanSleep(false)
	self.placer_parent:DoPeriodicTask(0, function(inst)
		if ThePlayer ~= nil and inst.move then inst.Transform:SetPosition(ThePlayer.Transform:GetWorldPosition()) end
    end)

    local UpdateControllerTargets = self.UpdateControllerTargets
	self.UpdateControllerTargets = function(self, dt, ...)
		UpdateControllerTargets(self, dt, ...)
		CancelControllerTargetWhenPlacing(self, dt)
    end

	local StartBuildPlacementMode = self.StartBuildPlacementMode
	self.StartBuildPlacementMode = function(...)
		StartBuildPlacementMode(...)
		if TheInput:ControllerAttached() then
			self.placer_parent:AddChild(self.placer)
            self.placer.Transform:SetPosition(0,0,0)
            self.placer_parent.move = not self.placer.onground and not self.placer.snap_to_meters
		end
    end
end

-- self: the placer component
function _M.GetPlacerOffset(placer, dt)
    local self = placer
    local input = TheInput
    -- only runs when controller is enabled
    if not input:ControllerAttached() then return Vector3(0, 0, 0) end

    if not self._printed then
        print(self.inst.prefab, "snap_to_tile=", self.snap_to_tile, "snap_to_meters=",self.snap_to_meters, "onground=", self.onground)
        self._printed = true
    end

    local placer_parent = ThePlayer.components.playercontroller.placer_parent
    if self.inst.parent ~= placer_parent then 
        placer_parent:AddChild(self.inst)
    end

    placer_parent.move = not self.snap_to_meters

    self.controller_offset = self.controller_offset or Vector3(0, 0, 0)

    local xdir = input:GetAnalogControlValue(CONTROL_INVENTORY_RIGHT) - input:GetAnalogControlValue(CONTROL_INVENTORY_LEFT)
    local ydir = input:GetAnalogControlValue(CONTROL_INVENTORY_UP) - input:GetAnalogControlValue(CONTROL_INVENTORY_DOWN)

    if math.abs(xdir) > DEADZONE or math.abs(ydir) > DEADZONE then
        local offset = self.controller_offset
        local camera = TheCamera or GetCamera()
        local dir = (camera:GetRightVec() * xdir - camera:GetDownVec() * ydir) * self.speed_mult
        --dir = dir:GetNormalized()
        if not self.snap_to_meters then
            self.controller_offset = offset+dir
        elseif GetTime() - (self.meters_move_time or 0) > 0.1 then
            dir = dir:GetNormalized()
            if math.abs(dir.x) > math.abs(dir.z) then
                self.controller_offset.x = self.controller_offset.x + dir.x
            else
                self.controller_offset.z = self.controller_offset.z + dir.z
            end
            self.meters_move_time = GetTime()
        end
        if self.speed_mult > 1 then 
            self.speed_mult = 1 
        else
            self.speed_mult = self.speed_mult + (self.speed_mult*OFFSET_SPEED*dt)
        end
    else -- reset speed
        self.speed_mult = 0.025
    end
    return self.controller_offset
end

return _M
