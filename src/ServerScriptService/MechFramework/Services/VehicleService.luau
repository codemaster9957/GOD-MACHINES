--!strict
-- Ground mobility simulation. Forces remain server authoritative and scale with mass, power, drivetrain and traction.
-- Passive wheels require drivetrain torque; powered hub/omni wheels require real electrical demand and supply.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PartRenderer = require(game.ReplicatedStorage.MechFramework.Shared.PartRenderer)

local Vehicle: any = { _angles = {}, _accumulator = 0 }

local GROUND_KINDS = table.freeze({
	Wheel=true, PoweredWheel=true, TrackDrive=true, TrackBogie=true, OmniWheel=true, Caster=true,
})

local function inputAxis(state: any, positive: string, negative: string): number
	return (state and state[positive] and 1 or 0) - (state and state[negative] and 1 or 0)
end

local function componentRoot(model: Model, id: string): BasePart?
	local component=model:FindFirstChild(id)
	if not component or not component:IsA("Model") then return nil end
	local root=component.PrimaryPart or component:FindFirstChild("Root")
	return if root and root:IsA("BasePart") then root else nil
end

local function ensureForce(root: BasePart): VectorForce
	local attachment=root:FindFirstChild("GMVehicleForceAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		if attachment then attachment:Destroy() end
		attachment=Instance.new("Attachment")
		attachment.Name="GMVehicleForceAttachment"
		attachment.Parent=root
	end
	local force=root:FindFirstChild("GMVehicleForce")
	if not force or not force:IsA("VectorForce") then
		if force then force:Destroy() end
		force=Instance.new("VectorForce")
		force.Name="GMVehicleForce"
		force.Attachment0=attachment
		force.RelativeTo=Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass=false
		force.Parent=root
	end
	return force
end

local function mechanicalTorque(mech: any): number
	local total=0
	for _,component in pairs(mech.Components) do
		local propulsion=component.Propulsion
		if propulsion and not component.Destroyed and (propulsion.Kind=="Engine" or propulsion.Kind=="Motor") then
			local fraction=math.clamp(tonumber(component.Metadata and component.Metadata.PropulsionFraction) or 0,0,1)
			total+=math.max(0,tonumber(propulsion.Torque) or 0)*fraction
		end
	end
	return total
end

local function isGroundContact(mobility: any): boolean
	return mobility~=nil and GROUND_KINDS[tostring(mobility.Kind or "")] == true
end

local function isDriven(mobility: any): boolean
	if not mobility then return false end
	return mobility.Drive==true or mobility.Kind=="TrackDrive" or mobility.Kind=="OmniWheel"
end

local function isIntegratedElectric(component: any): boolean
	-- A Power table by itself must never create propulsion. A positive electrical demand marks
	-- powered hub/omni modules that contain their own motor. Passive StandardWheel has Demand=0.
	return component.Power~=nil and (tonumber(component.Power.Demand) or 0)>0 and component.Mobility~=nil and isDriven(component.Mobility)
end

local function effectiveDriveTorque(component: any, availableMechanical: number, mechanicalShare: number): number
	local mobility=component.Mobility
	if not mobility then return 0 end
	local capacity=math.max(0,tonumber(mobility.DriveTorque) or 0)
	if capacity<=0 then return 0 end
	if isIntegratedElectric(component) then
		local fraction=math.clamp(tonumber(component.Metadata and component.Metadata.PowerFraction) or 0,0,1)
		return capacity*fraction
	end
	if availableMechanical<=0 then return 0 end
	return math.min(capacity,math.max(0,mechanicalShare))
end

function Vehicle:Init(container: any)
	self._mechs=container:Get("MechService")
end

function Vehicle:_stepModel(model: Model, dt: number)
	if model:GetAttribute("EditMode")~=false or not model.PrimaryPart then return end
	local mech=self._mechs:Get(model.Name)
	if not mech then return end
	local primary=model.PrimaryPart
	local availableTorque=mechanicalTorque(mech)
	local externallyDrivenCount=0
	local contactCount=0

	for _,component in pairs(mech.Components) do
		local mobility=component.Mobility
		if component.Destroyed or not mobility then continue end
		if isGroundContact(mobility) then contactCount+=1 end
		if isDriven(mobility) and not isIntegratedElectric(component) then externallyDrivenCount+=1 end
	end
	local mechanicalShare=if externallyDrivenCount>0 then availableTorque/externallyDrivenCount else 0
	local totalSteer,groundedSteer=0,0
	local wantsBrake=false
	local rayParams=RaycastParams.new()
	rayParams.FilterType=Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances={model}

	for id,component in pairs(mech.Components) do
		local mobility=component.Mobility
		if component.Destroyed or not mobility then continue end
		local root=componentRoot(model,id)
		if not root then continue end
		component.Metadata=component.Metadata or {}
		local state=component.Metadata.ControlState or {}
		local throttle=inputAxis(state,"ThrottleForward","ThrottleReverse")
		local strafe=inputAxis(state,"StrafeRight","StrafeLeft")
		local steer=inputAxis(state,"SteerRight","SteerLeft")
		local brake=state.Brake==true
		wantsBrake=wantsBrake or brake

		local force=ensureForce(root)
		force.Force=Vector3.zero
		if not isGroundContact(mobility) then
			-- Drivetrain/axle modules are engineering components, not invisible suspension points.
			continue
		end

		local radius=math.max(.35,tonumber(mobility.Radius) or 1)
		local travel=math.max(.05,tonumber(mobility.SuspensionTravel) or .25)
		local restDistance=radius+travel
		local rayLength=restDistance+.7
		local ray=Workspace:Raycast(root.Position,Vector3.new(0,-rayLength,0),rayParams)
		local grounded=ray~=nil
		local totalForce=Vector3.zero

		if grounded and ray then
			-- Progressive spring support with velocity damping, shared only across actual ground-contact modules.
			local distance=(root.Position-ray.Position).Magnitude
			local compression=math.clamp((restDistance-distance)/travel,0,1)
			if compression>0 then
				local divisor=math.max(1,contactCount)
				local support=(primary.AssemblyMass*Workspace.Gravity/divisor)*compression*1.35
				local damping=math.clamp(root.AssemblyLinearVelocity.Y*primary.AssemblyMass/divisor*.7,-support*.75,support*.75)
				totalForce+=Vector3.new(0,math.max(0,support-damping),0)
			end
		end

		if grounded and isDriven(mobility) then
			local driveTorque=effectiveDriveTorque(component,availableTorque,mechanicalShare)
			if driveTorque>0 then
				local grip=math.clamp(tonumber(mobility.Grip) or 1,.1,2.5)
				local driveVector=primary.CFrame.LookVector*throttle
				if mobility.Kind=="OmniWheel" then driveVector+=primary.CFrame.RightVector*strafe end
				if driveVector.Magnitude>1 then driveVector=driveVector.Unit end
				if driveVector.Magnitude>.001 then totalForce+=driveVector*(driveTorque*9.5*grip) end
			end
		end
		force.Force=totalForce

		-- Free casters and omni wheels are not fake steering axles. Only declared steerable modules turn the chassis.
		if grounded and steer~=0 and mobility.Steer==true and mobility.FreeCaster~=true then
			totalSteer+=steer
			groundedSteer+=1
		end

		if GROUND_KINDS[tostring(mobility.Kind or "")] then
			local localVelocity=primary.CFrame:VectorToObjectSpace(primary.AssemblyLinearVelocity)
			local rollingSpeed=if mobility.Kind=="OmniWheel" and math.abs(strafe)>math.abs(throttle) then localVelocity.X else -localVelocity.Z
			local key=model.Name..":"..id
			self._angles[key]=(self._angles[key] or 0)+(rollingSpeed/math.max(radius,.2))*dt
			local componentModel=model:FindFirstChild(id)
			if componentModel and componentModel:IsA("Model") then PartRenderer.SetSpinner(componentModel,"WheelSpinner",self._angles[key]) end
		end
	end

	if wantsBrake then
		local v=primary.AssemblyLinearVelocity
		local horizontal=Vector3.new(v.X,0,v.Z)*math.clamp(1-dt*5.5,0,.96)
		primary.AssemblyLinearVelocity=Vector3.new(horizontal.X,v.Y,horizontal.Z)
	end
	if groundedSteer>0 then
		local steer=math.clamp(totalSteer/groundedSteer,-1,1)
		local speed=primary.AssemblyLinearVelocity.Magnitude
		local response=math.clamp(speed/18,.15,1.2)
		local current=primary.AssemblyAngularVelocity
		primary.AssemblyAngularVelocity=Vector3.new(current.X,steer*1.65*response,current.Z)
	end
end

function Vehicle:Start()
	RunService.Heartbeat:Connect(function(dt)
		self._accumulator+=dt
		if self._accumulator<1/30 then return end
		local step=self._accumulator
		self._accumulator=0
		local assemblies=Workspace:FindFirstChild("MechAssemblies")
		if not assemblies then return end
		for _,model in ipairs(assemblies:GetChildren()) do if model:IsA("Model") then self:_stepModel(model,step) end end
	end)
end

return Vehicle
