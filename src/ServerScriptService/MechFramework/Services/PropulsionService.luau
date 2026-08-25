--!strict
-- Mounted thrust, drivetrain activity, shared fuel use and animated propulsion visuals.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PartRenderer = require(game.ReplicatedStorage.MechFramework.Shared.PartRenderer)

local Propulsion: any = { _angles = {}, _accumulator = 0 }

local function axis(state: any, positive: string, negative: string): number
	return (state and state[positive] and 1 or 0) - (state and state[negative] and 1 or 0)
end

local function componentModel(model: Model, id: string): Model?
	local value=model:FindFirstChild(id)
	return if value and value:IsA("Model") then value else nil
end

local function componentRoot(model: Model, id: string): BasePart?
	local comp=componentModel(model,id)
	if not comp then return nil end
	local root=comp.PrimaryPart or comp:FindFirstChild("Root")
	return if root and root:IsA("BasePart") then root else nil
end

local function ensureForce(root: BasePart): VectorForce
	local attachment=root:FindFirstChild("GMPropulsionAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		if attachment then attachment:Destroy() end
		attachment=Instance.new("Attachment"); attachment.Name="GMPropulsionAttachment"; attachment.Parent=root
	end
	local force=root:FindFirstChild("GMPropulsionForce")
	if not force or not force:IsA("VectorForce") then
		if force then force:Destroy() end
		force=Instance.new("VectorForce"); force.Name="GMPropulsionForce"; force.Attachment0=attachment; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=false; force.Parent=root
	end
	return force
end

local function mechanicalPower(mech: any): number
	local total=0
	for _,component in pairs(mech.Components) do
		local p=component.Propulsion
		if p and (p.Kind=="Engine" or p.Kind=="Motor") and not component.Destroyed then
			local fraction=math.clamp(tonumber(component.Metadata and component.Metadata.PropulsionFraction) or 0,0,1)
			total+=math.max(0,tonumber(p.MechanicalPower) or 0)*fraction
		end
	end
	return total
end

function Propulsion:Init(container: any)
	self._mechs=container:Get("MechService")
	self._fuel=container:Get("FuelService")
end

function Propulsion:_fuelFraction(mechId: string, propulsion: any, throttleMagnitude: number, dt: number): number
	local rate=math.max(0,tonumber(propulsion.FuelUse) or 0)
	if rate<=0 or throttleMagnitude<=0 then return 1 end
	local needed=rate*throttleMagnitude*math.max(0,dt)
	if needed<=0 then return 1 end
	local supplied=self._fuel:Consume(mechId,tostring(propulsion.FuelType or "Liquid"),needed,true)
	return math.clamp((tonumber(supplied) or 0)/needed,0,1)
end

function Propulsion:_stepModel(model: Model, dt: number)
	if model:GetAttribute("EditMode")~=false or not model.PrimaryPart then return end
	local mech=self._mechs:Get(model.Name)
	if not mech then return end

	-- Engines/motors establish the mechanical resource used by VehicleService and propellers.
	for _,component in pairs(mech.Components) do
		local p=component.Propulsion
		if component.Destroyed or not p or (p.Kind~="Engine" and p.Kind~="Motor") then continue end
		component.Metadata=component.Metadata or {}
		local state=component.Metadata.ControlState or {}
		local throttle=math.abs(axis(state,"ThrottleForward","ThrottleReverse"))
		local resourceFraction=1
		if p.Kind=="Motor" then resourceFraction=math.clamp(tonumber(component.Metadata.PowerFraction) or 0,0,1)
		else resourceFraction*=self:_fuelFraction(model.Name,p,throttle,dt) end
		component.Metadata.PropulsionFraction=throttle*resourceFraction
	end

	local mechPower=mechanicalPower(mech)
	local demand=0
	for _,component in pairs(mech.Components) do
		local p=component.Propulsion
		if p and not component.Destroyed and (p.Kind=="Propeller" or p.Kind=="LiftFan") then demand+=math.max(0,tonumber(p.MechanicalDemand) or 0) end
	end
	local mechanicalFraction=if demand>0 then math.clamp(mechPower/demand,0,1) else 1

	for id,component in pairs(mech.Components) do
		local p=component.Propulsion
		if component.Destroyed or not p then continue end
		local root=componentRoot(model,id)
		if not root then continue end
		component.Metadata=component.Metadata or {}
		local state=component.Metadata.ControlState or {}
		local kind=tostring(p.Kind or "")
		local throttle=axis(state,"ThrottleForward","ThrottleReverse")
		if kind=="LiftFan" then throttle=axis(state,"VerticalUp","VerticalDown") end
		if kind=="Jet" or kind=="Rocket" or kind=="Vector" then throttle=math.max(0,throttle) end

		local powerFraction=math.clamp(tonumber(component.Metadata.PowerFraction) or 1,0,1)
		if kind=="Engine" or kind=="Motor" then powerFraction=math.clamp(tonumber(component.Metadata.PropulsionFraction) or 0,0,1) end
		if kind=="Propeller" or kind=="LiftFan" then powerFraction*=mechanicalFraction end

		if kind~="Engine" and kind~="Motor" then
			local fuelFraction=self:_fuelFraction(model.Name,p,math.abs(throttle),dt)
			powerFraction*=fuelFraction
		end
		component.Metadata.PropulsionFraction=math.abs(throttle)*powerFraction

		local force=ensureForce(root)
		force.Force=Vector3.zero
		local magnitude=math.max(0,tonumber(p.Force) or 0)*throttle*powerFraction
		if magnitude~=0 then
			local localDirection=if typeof(p.Direction)=="Vector3" then p.Direction else Vector3.new(0,0,-1)
			if kind=="Vector" then
				local yaw=axis(state,"YawRight","YawLeft")
				local pitch=axis(state,"PitchUp","PitchDown")
				local degrees=math.rad(math.max(0,tonumber(p.GimbalDegrees) or 15))
				local transformed=CFrame.Angles(pitch*degrees,yaw*degrees,0):VectorToWorldSpace(localDirection)
				if transformed.Magnitude>.001 then localDirection=transformed.Unit end
			end
			force.Force=root.CFrame:VectorToWorldSpace(localDirection)*magnitude
		end

		local visual=componentModel(model,id)
		if visual then
			local key=model.Name..":"..id
			self._angles[key]=(self._angles[key] or 0)+dt*(2+math.abs(throttle)*32*math.max(.15,powerFraction))
			PartRenderer.SetSpinner(visual,"EngineSpinner",self._angles[key])
			PartRenderer.SetSpinner(visual,"TurbineSpinner",self._angles[key])
			PartRenderer.SetSpinner(visual,"PropellerSpinner",self._angles[key])
		end
	end
end

function Propulsion:Start()
	RunService.Heartbeat:Connect(function(dt)
		self._accumulator+=dt
		if self._accumulator<1/30 then return end
		local step=self._accumulator; self._accumulator=0
		local assemblies=Workspace:FindFirstChild("MechAssemblies")
		if not assemblies then return end
		for _,model in ipairs(assemblies:GetChildren()) do if model:IsA("Model") then self:_stepModel(model,step) end end
	end)
end

return Propulsion
