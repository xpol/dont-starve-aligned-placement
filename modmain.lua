local CAPY_DLC, IsDLCEnabled = GLOBAL.CAPY_DLC, GLOBAL.IsDLCEnabled
local DLC002 = IsDLCEnabled(CAPY_DLC)

local unpack, Vector3, GetPlayer, GetWorld = table.unpack or GLOBAL.unpack, GLOBAL.Vector3,GLOBAL.GetPlayer, GLOBAL.GetWorld

--local KEY_CTRL = GLOBAL.KEY_CTRL

local SNAP, ALIGN = 0.5, 0.1

local function OnlyPrefab(prefab)
	return function(inst)
		return inst.prefab == prefab
	end
end

local function PrefabMatch(pattern)
	return function(inst)
		return inst.prefab:match(pattern) ~= nil
	end
end

local function PrefabStatus(prefab, status)
	return function(inst)
		local inspectable = inst.components.inspectable
		return inst.prefab == prefab and inspectable and inspectable:GetStatus() == status
	end
end

local SNAP_INFO = {
	{OnlyPrefab('berrybush'), 'dug_berrybush_placer', 'dug_berrybush'},
	{OnlyPrefab('berrybush2'), 'dug_berrybush2_placer', 'dug_berrybush2'},
	{OnlyPrefab('sapling'), 'dug_sapling_placer', 'dug_sapling'},
	{OnlyPrefab('grass'), 'dug_grass_placer', 'dug_grass'},
	{OnlyPrefab('marsh_bush'), 'dug_marsh_bush_placer', 'dug_marsh_bush'},

	{PrefabMatch('^.+_farmplot$'), 'farmplot_placer'},
	{OnlyPrefab('slow_farmplot'), 'slow_farmplot_placer'},
	{OnlyPrefab('fast_farmplot'), 'fast_farmplot_placer'},
	{OnlyPrefab('ashfarmplot'), 'ashfarmplot_placer'},

	{PrefabStatus('pinecone', 'PLANTED'), 'pinecone_placer', 'pinecone'},
	{PrefabStatus('acorn', 'PLANTED'), 'acorn_placer', ''}
}

local function GenerateLookups(infos)
	local placers = {}
	local deployables = {}
	for _, v in ipairs(infos) do
		local checker, placer, deployable = unpack(v)
		placers[placer] = checker
		if deployable then deployables[deployable] = checker end
	end
	return placers, deployables
end


local PLACER_SNAPS, DEPLOYABLE_SNAPS = GenerateLookups(SNAP_INFO)

local function Align(v, step)
	return (v + step/2) - (v % step)
end

local function DistanceAxis(axis, a, b)
	return math.abs(a[axis] - b[axis])
end

local function NearestAtAxis(axis, base, can_snap)
  local x, y, z = base:Get()
	local entities = GLOBAL.TheSim:FindEntities(x, y, z, 20)
	local target, d = nil, math.huge
	for _, e in ipairs(entities) do
		if can_snap(e) then
			local newd = DistanceAxis(axis, e:GetPosition(), base)
			if not target or d > newd then
				target, d = e, newd
			end
		end
	end
	return target, d
end

local function SnapAxis(axis, position, can_snap)
	local t, d = NearestAtAxis(axis, position, can_snap)

	if t and d < SNAP then
      return t:GetPosition()[axis]
	end
	return Align(position[axis], ALIGN)
end

local function Snap(position, can_snap)
  if not can_snap or not position then return false end

  local x = SnapAxis('x', position, can_snap)
  local z = SnapAxis('z', position, can_snap)
  return true, Vector3(x, position.y, z)
end


-- Patched version of Placer:OnUpdate with respect of self.selected_pos
local function DLC001PlacerOnUpdate(self, _)
	local can_snap = PLACER_SNAPS[self.inst.prefab]
	if not GLOBAL.TheInput:ControllerAttached() then
		local pt = self.selected_pos or GLOBAL.TheInput:GetWorldPosition()
		local ok, to = Snap(pt, can_snap)
		if ok then
			pt = to
		elseif self.snap_to_tile and GetWorld().Map then
			pt = Vector3(GetWorld().Map:GetTileCenterPoint(pt:Get()))
		elseif self.snap_to_meters then
			pt = Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
		end
		self.inst.Transform:SetPosition(pt:Get())
	else
		local p = Vector3(GetPlayer().entity:LocalToWorldSpace(1,0,0))
		local ok, to = Snap(p, can_snap)
		if ok then
			self.inst.Transform:SetPosition(to:Get())
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


local function DLC002PlacerOnUpdate(self, _)
	print('DLC002PlacerOnUpdate:', self.inst.prefab)
	local can_snap = PLACER_SNAPS[self.inst.prefab]
	if not GLOBAL.TheInput:ControllerAttached() then
		local pt = self.selected_pos or GLOBAL.TheInput:GetWorldPosition()
		local ok, to = Snap(pt, can_snap)
		if ok then
			pt = to
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
		local ok, to = Snap(p, can_snap)
		if ok then
			self.inst.Transform:SetPosition(to:Get())
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
		local ok, to = Snap(pt, OnlyPrefab(recipe.name))
		if ok then pt = to end
		return CanBuildAtPoint(self, pt, recipe)
	end

	local MakeRecipe = builder.MakeRecipe
	function builder:MakeRecipe(recipe, pt, ...)
		local ok, to = Snap(pt, OnlyPrefab(recipe.name))
		if ok then pt = to end
		return MakeRecipe(self, recipe, pt, ...)
	end
end)

AddComponentPostInit("deployable", function(deployable)
	local CanDeploy, Deploy = deployable.CanDeploy, deployable.Deploy
	function deployable:CanDeploy(pt)
		local ok, to = Snap(pt, DEPLOYABLE_SNAPS[self.inst.prefab])
		if ok then pt = to end
		return CanDeploy(self, pt)
	end

	function deployable:Deploy(pt, deployer)
		local ok, to = Snap(pt, DEPLOYABLE_SNAPS[self.inst.prefab])
		if ok then pt = to end
		return Deploy(self, pt, deployer)
	end
end)
