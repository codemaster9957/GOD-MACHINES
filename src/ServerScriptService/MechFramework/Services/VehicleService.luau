--!strict
-- Ground mobility simulation. Forces remain server authoritative and scale with mass, power and traction.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PartRenderer = require(game.ReplicatedStorage.MechFramework.Shared.PartRenderer)

local Vehicle: any = { _angles = {}, _accumulator = 0 }

local function inputAxis(state: any, positive: string, negative: string): number
	return (state and state[positive] and 1 or 0) - (state and state[negative] and 1 or 0)
end

local function componentRoot(model: Model, id: string): BasePart?
	local component = model:FindFirstChild(id)
	if not component or not component:IsA("Model") then return nil end
	local root = component.PrimaryPart or component:FindFirstChild("Root")
	return if root and root:IsA("BasePart") then root else nil
end

local function ensureForce(root: BasePart): VectorForce
	local attachment = root:FindFirstChild("GMVehicleForceAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		if attachment then attachment:Destroy() end
		attachment = Instance.new("Attachment"); attachment.Name="GMVehicleForceAttachment"; attachment.Parent=root
	end
	local force = root:FindFirstChild("GMVehicleForce")
	if not force or not force:IsA("VectorForce") then
		if force then force:Destroy() end
		force=Instance.new("VectorForce"); force.Name="GMVehicleForce"; force.Attachment0=attachment; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=false; force.Parent=root
	end
	return force
end

local function mechanicalTorque(mech: any): number
	local total = 0
	for _, component in pairs(mech.Components) do
		local propulsion = component.Propulsion
		if propulsion and (propulsion.Kind=="Engine" or propulsion.Kind=="Motor") then
			local fraction = math.clamp(tonumber(component.Metadata and component.Metadata.PowerFraction) or 1,0,1)
			if propulsion.Kind=="Engine" then fraction=1 end
			total += math.max(0,tonumber(propulsion.Torque) or 0)*fraction
		end
	end
	return total
end

function Vehicle:Init(container: any)
	self._mechs = container:Get("MechService")
end

function Vehicle:_stepModel(model: Model, dt: number)
	if model:GetAttribute("EditMode") ~= false or not model.PrimaryPart then return end
	local mech = self._mechs:Get(model.Name)
	if not mech then return end
	local primary = model.PrimaryPart
	local availableTorque = mechanicalTorque(mech)
	local driven = {}
	local steered = {}
	for id, component in pairs(mech.Components) do
		if component.Destroyed or not component.Mobility then continue end
		local mobility = component.Mobility
		if mobility.Drive==true or mobility.Kind=="TrackDrive" or mobility.Kind=="OmniWheel" then table.insert(driven,id) end
		if mobility.Steer==true or mobility.Kind=="Caster" or mobility.Kind=="OmniWheel" then table.insert(steered,id) end
	end
	local torqueShare = if #driven>0 and availableTorque>0 then availableTorque/#driven else math.huge
	local totalSteer = 0
	local groundedSteer = 0
	local rayParams = RaycastParams.new(); rayParams.FilterType=Enum.RaycastFilterType.Exclude; rayParams.FilterDescendantsInstances={model}

	for id, component in pairs(mech.Components) do
		local mobility = component.Mobility
		if component.Destroyed or not mobility then continue end
		local root = componentRoot(model,id)
		if not root then continue end
		local state = component.Metadata and component.Metadata.ControlState or {}
		local throttle = inputAxis(state,"ThrottleForward","ThrottleReverse")
		local steer = inputAxis(state,"SteerRight","SteerLeft")
		local brake = state.Brake==true
		local radius = math.max(.4,tonumber(mobility.Radius) or 1)
		local travel = math.max(0,tonumber(mobility.SuspensionTravel) or .25)
		local ray = Workspace:Raycast(root.Position,Vector3.new(0,-(radius+travel+.65),0),rayParams)
		local grounded = ray~=nil
		local force = ensureForce(root)
		force.Force = Vector3.zero

		if grounded and (mobility.Drive==true or mobility.Kind=="TrackDrive" or mobility.Kind=="OmniWheel") and math.abs(throttle)>.001 then
			local ownTorque = math.max(0,tonumber(mobility.DriveTorque) or 0)
			local effective = math.min(ownTorque,torqueShare)
			if availableTorque<=0 and component.Power then
				local fraction=math.clamp(tonumber(component.Metadata.PowerFraction) or 0,0,1)
				effective=ownTorque*fraction
			end
			local grip=math.clamp(tonumber(mobility.Grip) or 1,.1,2.5)
			local forward=primary.CFrame.LookVector
			force.Force=forward*(effective*9.5*grip*throttle)
		end

		if grounded and steer~=0 and mobility.Steer==true then totalSteer+=steer; groundedSteer+=1 end
		if brake and grounded then
			local v=primary.AssemblyLinearVelocity
			primary.AssemblyLinearVelocity=Vector3.new(v.X*.88,v.Y,v.Z*.88)
		end

		if mobility.Kind=="Wheel" or mobility.Kind=="TrackDrive" or mobility.Kind=="TrackBogie" or mobility.Kind=="OmniWheel" or mobility.Kind=="Caster" then
			local speed=primary.AssemblyLinearVelocity:Dot(primary.CFrame.LookVector)
			local key=model.Name..":"..id
			self._angles[key]=(self._angles[key] or 0)+(speed/math.max(radius,.2))*dt
			local componentModel=model:FindFirstChild(id)
			if componentModel and componentModel:IsA("Model") then PartRenderer.SetSpinner(componentModel,"WheelSpinner",self._angles[key]) end
		end
	end

	if groundedSteer>0 then
		local steer=math.clamp(totalSteer/groundedSteer,-1,1)
		local speed=primary.AssemblyLinearVelocity.Magnitude
		local response=math.clamp(speed/18,.2,1.2)
		local current=primary.AssemblyAngularVelocity
		primary.AssemblyAngularVelocity=Vector3.new(current.X,steer*1.65*response,current.Z)
	end
end

function Vehicle:Start()
	RunService.Heartbeat:Connect(function(dt)
		self._accumulator+=dt
		if self._accumulator<1/30 then return end
		local step=self._accumulator; self._accumulator=0
		local assemblies=Workspace:FindFirstChild("MechAssemblies")
		if not assemblies then return end
		for _, model in ipairs(assemblies:GetChildren()) do if model:IsA("Model") then self:_stepModel(model,step) end end
	end)
end

return Vehicle
