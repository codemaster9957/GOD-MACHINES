--!strict
-- Server-authoritative destruction orchestration. Components persist as stateful procedural wreckage.
-- Only canonical inter-component connection welds are severed; internal renderer welds stay intact.

local Workspace = game:GetService("Workspace")

local Destruction: any = {
	_events = {},
	_processing = {} :: {[string]: boolean},
	_disabled = {} :: {[string]: boolean},
}

local function componentKey(mechId: string, componentId: string): string return mechId..":"..componentId end

local function assemblyModel(mechId: string): Model?
	local root=Workspace:FindFirstChild("MechAssemblies")
	local model=root and root:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end

local function componentModel(mechId: string, componentId: string): Model?
	local model=assemblyModel(mechId)
	local value=model and model:FindFirstChild(componentId)
	return if value and value:IsA("Model") then value else nil
end

local function getPart(mechId: string, componentId: string): BasePart?
	local component=componentModel(mechId,componentId)
	if not component then return nil end
	local root=component.PrimaryPart or component:FindFirstChild("Root")
	return if root and root:IsA("BasePart") and root:GetAttribute("ComponentRoot")==true then root else nil
end

local function instanceComponent(instance: Instance?): (string?, string?)
	local current=instance
	while current do
		local mechId=current:GetAttribute("MechId")
		local componentId=current:GetAttribute("ComponentId")
		if type(mechId)=="string" and type(componentId)=="string" then return mechId,componentId end
		current=current.Parent
	end
	return nil,nil
end

local function isWeapon(component: any): boolean
	local metadata=component.Metadata or {}
	return component.Combat~=nil or metadata.Role=="Weapon" or metadata.ComponentClass=="Weapon"
end

function Destruction:Init(container: any)
	self._mechs=container:Get("MechService")
	self._physics=container:Get("PhysicsService")
	for _,name in ipairs({"ComponentDamaged","ComponentDestroyed","AssemblyDetached","MechDisabled","EffectRequested"}) do self._events[name]=Instance.new("BindableEvent") end
end
function Destruction:Start() end
function Destruction:GetSignal(name: string): RBXScriptSignal? local event=self._events[name]; return event and event.Event or nil end
function Destruction:_emit(name: string,payload:any) local event=self._events[name]; if event then event:Fire(payload) end end

function Destruction:OnComponentDamaged(mechId:string,componentId:string,amount:number,context:any)
	local component=self._mechs:GetComponent(mechId,componentId)
	if not component then return end
	local part=getPart(mechId,componentId)
	if part then part:SetAttribute("Health",component.Health); part:SetAttribute("DamageState",component.DamageState or "Damaged") end
	local payload={MechId=mechId,ComponentId=componentId,Amount=amount,Health=component.Health,DamageType=context.DamageType or "Kinetic",Position=context.Position}
	self:_emit("ComponentDamaged",payload)
	self:_emit("EffectRequested",{Effect=if component.DamageState=="Critical" then "Smoke" else "Sparks",Data=payload})
end

function Destruction:_destroyConnectionWeld(mechId:string,connectionId:string)
	local model=assemblyModel(mechId)
	if not model then return end
	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") and tostring(descendant:GetAttribute("ConnectionId") or "")==connectionId then
			descendant:Destroy()
		end
	end
end

local function clearOccupiedBy(component:any,otherId:string)
	for _,node in pairs(component and component.Metadata and component.Metadata.AttachmentNodes or {}) do
		if node.OccupiedBy==otherId then node.OccupiedBy=nil end
	end
end

function Destruction:_removeDestroyedEdges(mechId:string,mech:any,componentId:string)
	local component=mech.Components[componentId]
	if not component then return end
	local edgeIds={}
	for edgeId in pairs(component.Connections or {}) do table.insert(edgeIds,edgeId) end
	for _,edgeId in ipairs(edgeIds) do
		local edge=mech.Connections[edgeId]
		if edge then
			local a,b=mech.Components[edge.A],mech.Components[edge.B]
			if a then clearOccupiedBy(a,edge.B) end
			if b then clearOccupiedBy(b,edge.A) end
			if mech.Adjacency[edge.A] then mech.Adjacency[edge.A][edge.B]=nil end
			if mech.Adjacency[edge.B] then mech.Adjacency[edge.B][edge.A]=nil end
			if a then a.Connections[edgeId]=nil end
			if b then b.Connections[edgeId]=nil end
			self:_destroyConnectionWeld(mechId,edgeId)
			mech.Connections[edgeId]=nil
		end
	end
end

function Destruction:_primaryRoot(mech:any): string?
	local explicit: string?=nil
	local pilotId: string?=nil
	local pilotPriority=-math.huge
	local heavyId: string?=nil
	local heavyMass=-math.huge
	for id,component in pairs(mech.Components) do
		if component.Destroyed or (component.Metadata and component.Metadata.Detached) then continue end
		local meta=component.Metadata or {}
		if meta.PrimaryAssembly==true or meta.IsPrimary==true or meta.Role=="Core" then explicit=explicit or id end
		if component.Pilot then
			local priority=tonumber(component.Pilot.Priority) or 0
			if priority>pilotPriority then pilotPriority=priority; pilotId=id end
		end
		local mass=tonumber(component.Mass) or 0
		if mass>heavyMass then heavyMass=mass; heavyId=id end
	end
	return explicit or pilotId or heavyId
end

function Destruction:_anchoredSet(mech:any): {[string]:boolean}
	local rootId=self:_primaryRoot(mech)
	if not rootId then return {} end
	local anchored={[rootId]=true}
	local queue={rootId}
	local head=1
	while queue[head] do
		local current=queue[head]; head+=1
		for neighbor in pairs(mech.Adjacency[current] or {}) do
			local component=mech.Components[neighbor]
			if component and not component.Destroyed and not anchored[neighbor] then anchored[neighbor]=true; table.insert(queue,neighbor) end
		end
	end
	return anchored
end

function Destruction:_detachOrphans(mechId:string,mech:any)
	local anchored=self:_anchoredSet(mech)
	local visited={}
	for id,component in pairs(mech.Components) do
		if component.Destroyed or anchored[id] or visited[id] or (component.Metadata and component.Metadata.Detached) then continue end
		local group,queue,head={}, {id},1
		visited[id]=true
		while queue[head] do
			local current=queue[head]; head+=1; table.insert(group,current)
			for neighbor in pairs(mech.Adjacency[current] or {}) do
				local nextComponent=mech.Components[neighbor]
				if nextComponent and not nextComponent.Destroyed and not anchored[neighbor] and not visited[neighbor] then visited[neighbor]=true; table.insert(queue,neighbor) end
			end
		end
		for _,detachedId in ipairs(group) do
			local detached=mech.Components[detachedId]
			detached.Metadata=detached.Metadata or {}; detached.Metadata.Detached=true; detached.Metadata.Operational=false
			-- Boundary structural welds were already removed with their graph edges. Preserve all
			-- internal connection welds so the orphan remains one coherent wreckage assembly.
			local part=getPart(mechId,detachedId)
			if part then part.Anchored=false; part:SetAttribute("Detached",true); part:SetAttribute("DamageState",detached.DamageState or "Detached") end
		end
		local payload={MechId=mechId,ComponentIds=group,Count=#group}
		self:_emit("AssemblyDetached",payload); self:_emit("EffectRequested",{Effect="DetachedCables",Data=payload})
	end
end

function Destruction:_evaluateDisabled(mechId:string,mech:any)
	local hadWeapon,operationalWeapon=false,false
	for _,component in pairs(mech.Components) do
		if isWeapon(component) then hadWeapon=true; if not component.Destroyed and not (component.Metadata and component.Metadata.Detached) then operationalWeapon=true end end
	end
	mech.Metadata=mech.Metadata or {}; mech.Metadata.WasCombatCapable=mech.Metadata.WasCombatCapable or hadWeapon
	local disabled=mech.Metadata.WasCombatCapable==true and not operationalWeapon
	mech.Metadata.CombatDisabled=disabled
	if disabled and not self._disabled[mechId] then self._disabled[mechId]=true; self:_emit("MechDisabled",{MechId=mechId,Reason="NoOperationalWeapons"})
	elseif not disabled then self._disabled[mechId]=nil end
end

function Destruction:HandleDestroyed(mechId:string,componentId:string,context:any)
	local key=componentKey(mechId,componentId)
	if self._processing[key] then return end
	self._processing[key]=true
	local mech=self._mechs:Get(mechId)
	local component=mech and mech.Components[componentId]
	if not mech or not component then self._processing[key]=nil; return end
	component.Destroyed=true; component.DamageState="Destroyed"; component.Metadata=component.Metadata or {}; component.Metadata.Operational=false; component.Metadata.DestroyedAt=os.clock()
	local part=getPart(mechId,componentId)
	self:_removeDestroyedEdges(mechId,mech,componentId)
	if part then part:SetAttribute("Destroyed",true); part:SetAttribute("DamageState","Destroyed"); part.Anchored=false end
	self:_detachOrphans(mechId,mech); self:_evaluateDisabled(mechId,mech)
	self._mechs:MarkChanged(mechId); self._physics:MarkDirty(mechId)
	local payload={MechId=mechId,ComponentId=componentId,DamageType=context.DamageType or "Kinetic",Position=context.Position}
	self:_emit("ComponentDestroyed",payload); self:_emit("EffectRequested",{Effect="BreakingSound",Data=payload})

	local utility=component.Utility or {}
	local volatile=component.Metadata.AmmoExplosion or component.Metadata.Volatile or utility.Kind=="AmmoStorage" or utility.Kind=="FuelTank"
	if volatile then
		local remainingFuel=component.Fuel and math.max(0,tonumber(component.Fuel.Amount) or 0) or 0
		local utilityCapacity=math.max(0,tonumber(utility.Capacity) or 0)
		local radius=tonumber(component.Metadata.ExplosionRadius) or (if utility.Kind=="FuelTank" then 14 else 11)
		local baseDamage=if utility.Kind=="FuelTank" then 35+remainingFuel*.35 elseif utility.Kind=="AmmoStorage" then 45+utilityCapacity*.28 else math.max(25,component.MaxHealth)
		local damage=tonumber(component.Metadata.ExplosionDamage) or baseDamage
		local position=context.Position or (part and part.Position)
		task.defer(function()
			self:ApplyExplosion(position,radius,damage,{Source=componentId,SourceMechId=mechId,DamageType="Explosive",IgnoreMechId=nil})
		end)
	end
	self._processing[key]=nil
end

function Destruction:ApplyExplosion(position:Vector3?,radius:number,damage:number,context:any):number
	if typeof(position)~="Vector3" or radius<=0 or damage<=0 then return 0 end
	context=context or {}
	local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Exclude; overlap.MaxParts=math.clamp(math.floor(tonumber(context.MaxParts) or 256),1,512)
	local sourceComponent=if type(context.SourceMechId)=="string" and type(context.Source)=="string" then componentModel(context.SourceMechId,context.Source) else nil
	if sourceComponent then overlap.FilterDescendantsInstances={sourceComponent} end
	local seen,targets={},{}
	for _,part in ipairs(Workspace:GetPartBoundsInRadius(position,radius,overlap)) do
		local mechId,componentId=instanceComponent(part)
		if type(mechId)=="string" and type(componentId)=="string" and mechId~=context.IgnoreMechId then
			local key=componentKey(mechId,componentId)
			if not seen[key] then seen[key]=true; table.insert(targets,{MechId=mechId,ComponentId=componentId,Part=part}) end
		end
	end
	local applied=0
	for _,target in ipairs(targets) do
		local targetRoot=getPart(target.MechId,target.ComponentId) or target.Part
		local offset=targetRoot.Position-position
		local distance=offset.Magnitude
		local rayParams=RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude
		if sourceComponent then rayParams.FilterDescendantsInstances={sourceComponent} end
		local obstruction=if distance>.01 then Workspace:Raycast(position,offset,rayParams) else nil
		if obstruction then
			local blockMech,blockComponent=instanceComponent(obstruction.Instance)
			if blockMech~=target.MechId or blockComponent~=target.ComponentId then continue end
		end
		local amount=damage*(1-math.clamp(distance/radius,0,1))
		if amount>0 and self._damage and self._damage:Apply(target.MechId,target.ComponentId,amount,{Source=context.Source or "Explosion",DamageType="Explosive",Position=position,Penetration=context.Penetration}) then applied+=1 end
	end
	self:_emit("EffectRequested",{Effect="Explosion",Data={Position=position,Radius=radius}})
	return applied
end

function Destruction:SetDamageService(service:any) self._damage=service end
return Destruction
