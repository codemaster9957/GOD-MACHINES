--!strict
-- Server-authoritative destruction orchestration. Components persist as stateful wreckage.
local Workspace = game:GetService("Workspace")

local Destruction: any = {
	_events = {},
	_processing = {} :: {[string]: boolean},
	_disabled = {} :: {[string]: boolean},
}

local function componentKey(mechId: string, componentId: string): string
	return mechId .. ":" .. componentId
end

local function getPart(mechId: string, componentId: string): BasePart?
	local root = Workspace:FindFirstChild("MechAssemblies")
	local model = root and root:FindFirstChild(mechId)
	if not model then return nil end
	local instance = model:FindFirstChild(componentId, true)
	return if instance and instance:IsA("BasePart") then instance else nil
end

local function isPrimary(component: any): boolean
	local metadata = component.Metadata or {}
	return not component.Destroyed and (metadata.PrimaryAssembly == true or metadata.IsPrimary == true or metadata.Role == "Core" or metadata.Role == "Cockpit")
end

local function isWeapon(component: any): boolean
	local metadata = component.Metadata or {}
	return component.Combat ~= nil or metadata.Role == "Weapon" or metadata.ComponentClass == "Weapon"
end

function Destruction:Init(container: any)
	self._mechs = container:Get("MechService")
	self._physics = container:Get("PhysicsService")
	for _, name in {"ComponentDamaged", "ComponentDestroyed", "AssemblyDetached", "MechDisabled", "EffectRequested"} do
		self._events[name] = Instance.new("BindableEvent")
	end
end

function Destruction:Start()
	-- DamageService is resolved after every service has completed Init, avoiding trusted client paths.
end

function Destruction:GetSignal(name: string): RBXScriptSignal?
	local event = self._events[name]
	return event and event.Event or nil
end

function Destruction:_emit(name: string, payload: any)
	local event = self._events[name]
	if event then event:Fire(payload) end
end

function Destruction:OnComponentDamaged(mechId: string, componentId: string, amount: number, context: any)
	local component = self._mechs:GetComponent(mechId, componentId)
	if not component then return end
	local part = getPart(mechId, componentId)
	if part then
		part:SetAttribute("Health", component.Health)
		part:SetAttribute("DamageState", component.DamageState or "Damaged")
	end
	local payload = {MechId = mechId, ComponentId = componentId, Amount = amount, Health = component.Health, DamageType = context.DamageType or "Kinetic", Position = context.Position}
	self:_emit("ComponentDamaged", payload)
	self:_emit("EffectRequested", {Effect = if component.DamageState == "Critical" then "Smoke" else "Sparks", Data = payload})
end

function Destruction:_removeDestroyedEdges(mech: any, componentId: string)
	local edgeIds = {}
	for edgeId in mech.Components[componentId].Connections or {} do table.insert(edgeIds, edgeId) end
	for _, edgeId in edgeIds do
		local edge = mech.Connections[edgeId]
		if edge then
			if mech.Adjacency[edge.A] then mech.Adjacency[edge.A][edge.B] = nil end
			if mech.Adjacency[edge.B] then mech.Adjacency[edge.B][edge.A] = nil end
			if mech.Components[edge.A] then mech.Components[edge.A].Connections[edgeId] = nil end
			if mech.Components[edge.B] then mech.Components[edge.B].Connections[edgeId] = nil end
			mech.Connections[edgeId] = nil
		end
	end
end

function Destruction:_anchoredSet(mech: any): {[string]: boolean}
	local anchored: {[string]: boolean} = {}
	local queue = {}
	for id, component in mech.Components do
		if isPrimary(component) then anchored[id] = true; table.insert(queue, id) end
	end
	-- Legacy builds without an explicit primary keep their largest surviving connected assembly.
	if #queue == 0 then
		local fallbackId, fallbackMass = nil, -1
		for id, component in mech.Components do
			if not component.Destroyed and (tonumber(component.Mass) or 0) > fallbackMass then fallbackId, fallbackMass = id, tonumber(component.Mass) or 0 end
		end
		if fallbackId then anchored[fallbackId] = true; table.insert(queue, fallbackId) end
	end
	local head = 1
	while queue[head] do
		local current = queue[head]; head += 1
		for neighbor in mech.Adjacency[current] or {} do
			local component = mech.Components[neighbor]
			if component and not component.Destroyed and not anchored[neighbor] then anchored[neighbor] = true; table.insert(queue, neighbor) end
		end
	end
	return anchored
end

function Destruction:_detachOrphans(mechId: string, mech: any)
	local anchored = self:_anchoredSet(mech)
	local visited: {[string]: boolean} = {}
	for id, component in mech.Components do
		if component.Destroyed or anchored[id] or visited[id] then continue end
		local group, queue, head = {}, {id}, 1; visited[id] = true
		while queue[head] do
			local current = queue[head]; head += 1; table.insert(group, current)
			for neighbor in mech.Adjacency[current] or {} do
				local nextComponent = mech.Components[neighbor]
				if nextComponent and not nextComponent.Destroyed and not anchored[neighbor] and not visited[neighbor] then visited[neighbor] = true; table.insert(queue, neighbor) end
			end
		end
		for _, detachedId in group do
			local detached = mech.Components[detachedId]
			detached.Metadata = detached.Metadata or {}; detached.Metadata.Detached = true; detached.Metadata.Operational = false
			local part = getPart(mechId, detachedId)
			if part then part.Anchored = false; part:SetAttribute("Detached", true); part:SetAttribute("DamageState", detached.DamageState or "Detached") end
		end
		local payload = {MechId = mechId, ComponentIds = group, Count = #group}
		self:_emit("AssemblyDetached", payload)
		self:_emit("EffectRequested", {Effect = "DetachedCables", Data = payload})
	end
end

function Destruction:_evaluateDisabled(mechId: string, mech: any)
	local hadWeapon, operationalWeapon = false, false
	for _, component in mech.Components do
		if isWeapon(component) then
			hadWeapon = true
			if not component.Destroyed and not (component.Metadata and component.Metadata.Detached) then operationalWeapon = true end
		end
	end
	mech.Metadata = mech.Metadata or {}
	mech.Metadata.WasCombatCapable = mech.Metadata.WasCombatCapable or hadWeapon
	local disabled = mech.Metadata.WasCombatCapable == true and not operationalWeapon
	mech.Metadata.CombatDisabled = disabled
	if disabled and not self._disabled[mechId] then
		self._disabled[mechId] = true
		self:_emit("MechDisabled", {MechId = mechId, Reason = "NoOperationalWeapons"})
	elseif not disabled then self._disabled[mechId] = nil end
end

function Destruction:HandleDestroyed(mechId: string, componentId: string, context: any)
	local key = componentKey(mechId, componentId)
	if self._processing[key] then return end
	self._processing[key] = true
	local mech = self._mechs:Get(mechId)
	local component = mech and mech.Components[componentId]
	if not mech or not component then self._processing[key] = nil; return end
	component.Destroyed = true; component.DamageState = "Destroyed"
	component.Metadata = component.Metadata or {}; component.Metadata.Operational = false; component.Metadata.DestroyedAt = os.clock()
	local part = getPart(mechId, componentId)
	if part then
		part:SetAttribute("Destroyed", true); part:SetAttribute("DamageState", "Destroyed"); part.Anchored = false
		for _, child in part.Parent and part.Parent:GetDescendants() or {} do
			if child:IsA("WeldConstraint") and (child.Part0 == part or child.Part1 == part) then child:Destroy() end
		end
	end
	self:_removeDestroyedEdges(mech, componentId)
	self:_detachOrphans(mechId, mech)
	self:_evaluateDisabled(mechId, mech)
	self._mechs:MarkChanged(mechId); self._physics:MarkDirty(mechId)
	local payload = {MechId = mechId, ComponentId = componentId, DamageType = context.DamageType or "Kinetic", Position = context.Position}
	self:_emit("ComponentDestroyed", payload)
	self:_emit("EffectRequested", {Effect = "BreakingSound", Data = payload})
	local ammo = component.Metadata.AmmoExplosion or component.Metadata.Volatile
	if ammo then
		local radius = tonumber(component.Metadata.ExplosionRadius) or 12
		local damage = tonumber(component.Metadata.ExplosionDamage) or math.max(25, component.MaxHealth)
		task.defer(function() self:ApplyExplosion(context.Position or (part and part.Position), radius, damage, {Source = componentId, DamageType = "Explosive", IgnoreMechId = nil}) end)
	end
	self._processing[key] = nil
end

function Destruction:ApplyExplosion(position: Vector3?, radius: number, damage: number, context: any): number
	if typeof(position) ~= "Vector3" or radius <= 0 or damage <= 0 then return 0 end
	local params = OverlapParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.MaxParts = math.clamp(math.floor(tonumber(context.MaxParts) or 256), 1, 512)
	local seen: {[string]: boolean} = {}; local targets = {}
	for _, part in Workspace:GetPartBoundsInRadius(position, radius, params) do
		local mechId, componentId = part:GetAttribute("MechId"), part:GetAttribute("ComponentId")
		if type(mechId) == "string" and type(componentId) == "string" and mechId ~= context.IgnoreMechId then
			local key = componentKey(mechId, componentId)
			if not seen[key] then seen[key] = true; table.insert(targets, {MechId = mechId, ComponentId = componentId, Part = part}) end
		end
	end
	local applied = 0
	for _, target in targets do
		local offset = target.Part.Position - position; local distance = offset.Magnitude
		local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude; rayParams.FilterDescendantsInstances = {}
		local obstruction = if distance > 0.01 then Workspace:Raycast(position, offset, rayParams) else nil
		if obstruction and not obstruction.Instance:IsDescendantOf(target.Part) and obstruction.Instance ~= target.Part then continue end
		local amount = damage * (1 - math.clamp(distance / radius, 0, 1))
		if amount > 0 then
			local damageService = self._damage
			if damageService and damageService:Apply(target.MechId, target.ComponentId, amount, {Source = context.Source or "Explosion", DamageType = "Explosive", Position = position, Penetration = context.Penetration}) then applied += 1 end
		end
	end
	self:_emit("EffectRequested", {Effect = "Explosion", Data = {Position = position, Radius = radius}})
	return applied
end

function Destruction:SetDamageService(service: any)
	self._damage = service
end

return Destruction