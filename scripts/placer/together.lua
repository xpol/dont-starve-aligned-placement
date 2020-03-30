-- Patcher code for Don't Starve Together
-- steamapps\common\Don't Starve Together\data\databundles\scripts.zip\scripts\components\placer.lua
local function GenerateOnUpdate(snap, getControllerOffset)
return function(placer, dt)
    local self = placer
    if ThePlayer == nil then
        return
    end
    if not TheInput:ControllerAttached() then -- mouse
        local pt = self.selected_pos or TheInput:GetWorldPosition()
        if self.snap_to_tile then
            self.inst.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(pt:Get()))
        elseif self.snap_to_meters then
            self.inst.Transform:SetPosition(math.floor(pt.x) + .5, 0, math.floor(pt.z) + .5)
        else
            self.inst.Transform:SetPosition(snap(self, pt):Get()) -- MODIFIED LINE
        end
    else -- Controller
        local off = getControllerOffset(self, dt)
        if self.snap_to_tile then
            --Using an offset in this causes a bug in the terraformer functionality while using a controller.
            self.inst.Transform:SetPosition(TheWorld.Map:GetTileCenterPoint(ThePlayer.entity:LocalToWorldSpace(off:Get())))
        elseif self.snap_to_meters then
            local x, y, z = ThePlayer.entity:LocalToWorldSpace(self.offset, 0, 0)
            self.inst.Transform:SetPosition(math.floor(x + off.x) + .5, 0, math.floor(z + off.z) + .5)
        --elseif self.onground then
            --V2C: this will keep ground orientation accurate and smooth,
            --     but unfortunately position will be choppy compared to parenting
            --V2C: switched to WallUpdate, so should be smooth now
        --    local parent = ThePlayer.components.playercontroller.placer_parent.entity
        --    local pos = placer_parent:GetPosition() - snap(self, Vector3(ThePlayer.entity:LocalToWorldSpace(self.offset + off.x, 0, off.z)))
        --    ThePlayer.components.playercontroller.placer_parent.Transform:SetPosition(pos:Get()) 
        else
            local parent = ThePlayer.components.playercontroller.placer_parent.entity
            local pos = snap(self, Vector3(parent:LocalToWorldSpace(self.offset + off.x, 0, off.z)))
            self.inst.Transform:SetPosition(parent:WorldToLocalSpace(pos:Get()))
        end
    end

    if self.fixedcameraoffset ~= nil then
        local rot = self.fixedcameraoffset - TheCamera:GetHeading() -- rotate against the camera
        self.inst.Transform:SetRotation(rot)
        for i, v in ipairs(self.linked) do
            v.Transform:SetRotation(rot)
        end
    end

    if self.onupdatetransform ~= nil then
        self.onupdatetransform(self.inst)
    end

    if self.testfn ~= nil then
        self.can_build, self.mouse_blocked = self.testfn(self.inst:GetPosition(), self.inst:GetRotation())
    else
        self.can_build = true
        self.mouse_blocked = false
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    TriggerDeployHelpers(x, y, z, 64, self.recipe, self.inst)

    if self.can_build then
        if self.oncanbuild ~= nil then
            self.oncanbuild(self.inst, self.mouse_blocked)
            return
        end

        if self.mouse_blocked then
            self.inst:Hide()
            for i, v in ipairs(self.linked) do
                v:Hide()
            end
        else
            self.inst.AnimState:SetAddColour(.25, .75, .25, 0)
            self.inst:Show()
            for i, v in ipairs(self.linked) do
                v.AnimState:SetAddColour(.25, .75, .25, 0)
                v:Show()
            end
        end
    else
        if self.oncannotbuild ~= nil then
            self.oncannotbuild(self.inst, self.mouse_blocked)
            return
        end

        if self.mouse_blocked then
            self.inst:Hide()
            for i, v in ipairs(self.linked) do
                v:Hide()
            end
        else
            self.inst.AnimState:SetAddColour(.75, .25, .25, 0)
            self.inst:Show()
            for i, v in ipairs(self.linked) do
                v.AnimState:SetAddColour(.75, .25, .25, 0)
                v:Show()
            end
        end
    end
end
end

return GenerateOnUpdate
