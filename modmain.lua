local CAPY_DLC, IsDLCEnabled = GLOBAL.CAPY_DLC, GLOBAL.IsDLCEnabled
local DLC002 = IsDLCEnabled(CAPY_DLC)

local next, Vector3, GetPlayer, GetWorld = GLOBAL.next, GLOBAL.Vector3,GLOBAL.GetPlayer, GLOBAL.GetWorld

--local KEY_CTRL = GLOBAL.KEY_CTRL

local SNAP, ALIGN = 0.5, 0.1


local SNAP_INFO = {
	-- placer, deployable,  snap_to, snap_to, ...

	{'berrybush', placer = 'dug_berrybush_placer', deployable = 'dug_berrybush'},
	{'berrybush2', placer = 'dug_berrybush2_placer', deployable = 'dug_berrybush2'},
	{'sapling', placer = 'dug_sapling_placer', deployable = 'dug_sapling'},
	{'grass', placer = 'dug_grass_placer', deployable = 'dug_grass'},
	{'marsh_bush', placer = 'dug_marsh_bush_placer', deployable = 'dug_marsh_bush'},

	{'slow_farmplot', 'fast_farmplot', placer = 'farmplot_placer'},
	{'slow_farmplot', placer = 'slow_farmplot_placer'},
	{'fast_farmplot', placer = 'fast_farmplot_placer'},
	{'ashfarmplot', placer = 'ashfarmplot_placer'},

	{'', placer = 'pinecone_placer'}
}

local function GenerateLookups(infos)
	local placers = {}
	local deployables = {}
	for _, v in ipairs(infos) do
		local lookup = {}
		for i=1, #v do lookup[v[i]] = true end
		if v.placer then placers[v.placer] = lookup end
		if v.deployable then deployables[v.deployable] = lookup end
	end
	return placers, deployables
end


local PLACER_SNAPS, DEPLOYABLE_SNAPS = GenerateLookups(SNAP_INFO)

local function Align(v, step)
	return (v + step/2) - (v % step)
end

local function DistanceSquare(e, cx, cz)
	local x, _, z = e.Transform:GetWorldPosition()
	local dx, dz = cx - x, cz - z
	return dx*dx + dz*dz
end

local function NearestNeighbor(cx, cy, cz, required_neighbors)
	local entities = GLOBAL.TheSim:FindEntities(cx, cy, cz, 20)
	local target, dsq = nil, math.huge
	for _, e in ipairs(entities) do
		if required_neighbors[e.prefab] then
			local newdsq = DistanceSquare(e, cx, cz)
			if not target or dsq > newdsq then
				target, dsq = e, newdsq
			end
		end
	end
	return target
end

local function SnapToNeighbor(position, neighbors)
	if not neighbors or not next(neighbors) then return nil, false end
	if not position then return false end

	local cx, cy, cz = position:Get()
	local target = NearestNeighbor(cx, cy, cz, neighbors)

	if target then
		local x, _, z = target.Transform:GetWorldPosition()
		local dx, dz = math.abs(cx - x), math.abs(cz - z)
		if dx < SNAP or dz < SNAP then
			if dx < dz then
				cx, cz = x, Align(cz, ALIGN)
			else
				cx, cz = Align(cx, ALIGN), z
			end
			print(('Snap to %s at (%0.2f, %0.2f)'):format(target.prefab, cx, cz))
			return true, Vector3(cx, cy, cz)
		end
		return nil, position
	end

	return true, Vector3(Align(position.x, ALIGN), position.y, Align(position.z, ALIGN))
end

-- Patched version of Placer:OnUpdate with respect of self.selected_pos
local function DLC001PlacerOnUpdate(self, dt)
	print('DLC001PlacerOnUpdate:', self.inst.prefab)
	local snap_to = PLACER_SNAPS[self.inst.prefab]
	if not GLOBAL.TheInput:ControllerAttached() then
		local pt = self.selected_pos or GLOBAL.TheInput:GetWorldPosition()
		local ok, snapped = SnapToNeighbor(pt, snap_to)
		if ok then
			pt = snapped
		elseif self.snap_to_tile and GetWorld().Map then
			pt = Vector3(GetWorld().Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		end
		self.inst.Transform:SetPosition(pt:Get())
	else
		local p = Vector3(GetPlayer().entity:LocalToWorldSpace(1,0,0))
		local ok, snapped = SnapToNeighbor(p, snap_to)
		if ok then
			self.inst.Transform:SetPosition(snapped:Get())
		elseif self.snap_to_tile and GetWorld().Map then
			--Using an offset in this causes a bug in the terraformer functionality while using a controller.
			local pt = Vector3(GetPlayer().entity:LocalToWorldSpace(0,0,0))
			pt = Vector3(GetWorld().Map:GetTileCenterPoint(pt:Get()))
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.snap_to_meters then
			local pt = Vector3(GetPlayer().entity:LocalToWorldSpace(1,0,0))
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
			self.inst.Transform:SetPosition(pt:Get())
		else
			if self.inst.parent == nil then
				GetPlayer():AddChild(self.inst)
				self.inst.Transform:SetPosition(1,0,0)
			end
		end
	end

	self.can_build = true
	if self.testfn then
		self.can_build = self.testfn(Vector3(self.inst.Transform:GetWorldPosition()))
	end

	--self.inst.AnimState:SetMultColour(0,0,0,.5)

	local color = self.can_build and Vector3(.25,.75,.25) or Vector3(.75,.25,.25)
	self.inst.AnimState:SetAddColour(color.x, color.y, color.z ,0)

end


local function DLC002PlacerOnUpdate(self, dt)
	print('DLC002PlacerOnUpdate:', self.inst.prefab)
	local snap_to = PLACER_SNAPS[self.inst.prefab]
	if not GLOBAL.TheInput:ControllerAttached() then
		local pt = self.selected_pos or GLOBAL.TheInput:GetWorldPosition()
		local ok, snapped = SnapToNeighbor(pt, snap_to)
		if ok then
			pt = snapped
		elseif self.snap_to_tile and GetWorld().Map then
			pt = Vector3(GetWorld().Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		elseif self.snap_to_flood and GetWorld().Flooding then
			local center = Vector3(GetWorld().Flooding:GetTileCenterPoint(pt:Get()))
			pt.x = center.x
			pt.y = center.y
			pt.z = center.z
		end
		self.inst.Transform:SetPosition(pt:Get())
	else
		local offset = 1
		if self.recipe then
			if self.recipe.distance then
				offset = self.recipe.distance - 1
				offset = math.max(offset, 1)
			end
		elseif self.invobject then
			if self.invobject.components.deployable and self.invobject.components.deployable.deploydistance then
				offset = self.invobject.components.deployable.deploydistance
			end
		end

		local p = Vector3(GetPlayer().entity:LocalToWorldSpace(offset,0,0))
		local ok, snapped = SnapToNeighbor(p, snap_to)
		if ok then
			self.inst.Transform:SetPosition(snapped:Get())
		elseif self.snap_to_tile and GetWorld().Map then
			--Using an offset in this causes a bug in the terraformer functionality while using a controller.
			local pt = Vector3(GetPlayer().entity:LocalToWorldSpace(0,0,0))
			pt = Vector3(GetWorld().Map:GetTileCenterPoint(pt:Get()))
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.snap_to_meters then
			local pt = Vector3(GetPlayer().entity:LocalToWorldSpace(offset,0,0))
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.snap_to_flood then
			local pt = Vector3(GetPlayer().entity:LocalToWorldSpace(offset,0,0))
			local center = Vector3(GetWorld().Flooding:GetTileCenterPoint(pt:Get()))
			pt.x = center.x
			pt.y = center.y
			pt.z = center.z
			self.inst.Transform:SetPosition(pt:Get())
		elseif self.onground then
				--V2C: this will keep ground orientation accurate and smooth,
				--     but unfortunately position will be choppy compared to parenting
					self.inst.Transform:SetPosition(GLOBAL.ThePlayer.entity:LocalToWorldSpace(1, 0, 0))
		else
			if self.inst.parent == nil then
				GetPlayer():AddChild(self.inst)
				self.inst.Transform:SetPosition(offset,0,0)
			end
		end
	end

	if self.fixedcameraoffset then
					local rot = GLOBAL.TheCamera:GetHeading()
				 self.inst.Transform:SetRotation(-rot+self.fixedcameraoffset) -- rotate against the camera
		end

	self.can_build = true
	if self.testfn then
		self.can_build = self.testfn(Vector3(self.inst.Transform:GetWorldPosition()))
	end

	--self.inst.AnimState:SetMultColour(0,0,0,.5)

	local pt = self.selected_pos or GLOBAL.TheInput:GetWorldPosition()
	local ground = GetWorld()
		local tile = GLOBAL.GROUND.GRASS
		if ground and ground.Map then
				tile = ground.Map:GetTileAtPoint(pt:Get())
		end

		local onground = not ground.Map:IsWater(tile)

	if (not self.can_build and self.hide_on_invalid) or (self.hide_on_ground and onground) then
		self.inst:Hide()
	else
		self.inst:Show()
		local color = self.can_build and Vector3(.25,.75,.25) or Vector3(.75,.25,.25)
		self.inst.AnimState:SetAddColour(color.x, color.y, color.z ,0)
	end

end

AddComponentPostInit("placer", function(placer)
	placer.OnUpdate = DLC002 and DLC002PlacerOnUpdate or DLC001PlacerOnUpdate
end)

AddComponentPostInit("builder", function(builder)
	local CanBuildAtPoint = builder.CanBuildAtPoint

	function builder:CanBuildAtPoint(pt, recipe)
		print('CanBuildAtPoint: recipe', recipe.name)
		local snap_to = {[recipe.name] = true}
		local ok, snapped = SnapToNeighbor(pt, snap_to)
		if ok then pt = snapped end
		return CanBuildAtPoint(self, pt, recipe)
	end

	local MakeRecipe = builder.MakeRecipe
	function builder:MakeRecipe(recipe, pt, ...)
		local snap_to = {[recipe.name] = true}
		local ok, snapped = SnapToNeighbor(pt, snap_to)
		if ok then pt = snapped end
		return MakeRecipe(self, recipe, pt, ...)
	end
end)

AddComponentPostInit("deployable", function(deployable)
	local CanDeploy, Deploy = deployable.CanDeploy, deployable.Deploy
	function deployable:CanDeploy(pt)
		local ok, snapped = SnapToNeighbor(pt, DEPLOYABLE_SNAPS[self.inst.prefab])
		if ok then pt = snapped end
		return CanDeploy(self, pt)
	end

	function deployable:Deploy(pt, deployer)
		local ok, snapped = SnapToNeighbor(pt, DEPLOYABLE_SNAPS[self.inst.prefab])
		if ok then pt = snapped end
		return Deploy(self, pt, deployer)
	end
end)
