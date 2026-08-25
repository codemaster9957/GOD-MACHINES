--!strict
-- Bounded arcade aerodynamics: engineering choices matter without becoming numerically fragile.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Aero: any = { _accumulator = 0 }

local function axis(state: any, positive: string, negative: string): number
	return (state and state[positive] and 1 or 0) - (state and state[negative] and 1 or 0)
end

local function componentRoot(model: Model, id: string): BasePart?
	local component=model:FindFirstChild(id)
	if not component or not component:IsA("Model") then return nil end
	local root=component.PrimaryPart or component:FindFirstChild("Root")
	return if root and root:IsA("BasePart") then root else nil
end

local function ensureForce(root: BasePart): VectorForce
	local attachment=root:FindFirstChild("GMAeroAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		if attachment then attachment:Destroy() end
		attachment=Instance.new("Attachment"); attachment.Name="GMAeroAttachment"; attachment.Parent=root
	end
	local force=root:FindFirstChild("GMAeroForce")
	if not force or not force:IsA("VectorForce") then
		if force then force:Destroy() end
		force=Instance.new("VectorForce"); force.Name="GMAeroForce"; force.Attachment0=attachment; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=false; force.Parent=root
	end
	return force
end

function Aero:Init(container: any)
	self._mechs=container:Get("MechService")
end

function Aero:_stepModel(model: Model, dt: number)
	if model:GetAttribute("EditMode")~=false or not model.PrimaryPart then return end
	local mech=self._mechs:Get(model.Name)
	if not mech then return end
	local primary=model.PrimaryPart
	local controlPitch,controlYaw,controlRoll=0,0,0
	local controlCount=0

	for id, component in pairs(mech.Components) do
		local config=component.Aerodynamics
		if component.Destroyed or not config then continue end
		local root=componentRoot(model,id)
		if not root then continue end
		local velocity=root.AssemblyLinearVelocity
		local speed=velocity.Magnitude
		local force=ensureForce(root)
		force.Force=Vector3.zero
		if speed>2 then
			local kind=tostring(config.Kind or "")
			local area=math.max(0,tonumber(config.Area) or 0)
			local dragCoefficient=math.max(0,tonumber(config.DragCoefficient) or .05)
			local drag=-velocity.Unit*math.min(speed*speed*area*dragCoefficient*.16,primary.AssemblyMass*Workspace.Gravity*3.5)
			local total=drag
			if kind=="Wing" or kind=="Stabilizer" then
				local liftCoefficient=math.max(0,tonumber(config.LiftCoefficient) or .7)
				local attitude=math.clamp(root.CFrame.UpVector:Dot(Vector3.yAxis)*.65+.45,.05,1.1)
				local liftMagnitude=math.min(speed*speed*area*liftCoefficient*.42*attitude,primary.AssemblyMass*Workspace.Gravity*4)
				total+=root.CFrame.UpVector*liftMagnitude
			elseif kind=="Spoiler" then
				local down=math.max(0,tonumber(config.DownforceCoefficient) or .5)
				total-=root.CFrame.UpVector*math.min(speed*speed*area*down*.22,primary.AssemblyMass*Workspace.Gravity*2)
			elseif kind=="Airbrake" then
				local state=component.Metadata and component.Metadata.ControlState or {}
				if state.Brake==true then total+=-velocity.Unit*math.min(speed*speed*area*dragCoefficient*.8,primary.AssemblyMass*Workspace.Gravity*5) end
			end
			force.Force=total
		end

		if config.Kind=="ControlSurface" then
			local state=component.Metadata and component.Metadata.ControlState or {}
			local authority=math.clamp(tonumber(config.Authority) or 1,0,2)
			if config.Axis=="Pitch" then controlPitch+=axis(state,"PitchUp","PitchDown")*authority
			elseif config.Axis=="Yaw" then controlYaw+=axis(state,"YawRight","YawLeft")*authority
			elseif config.Axis=="Roll" then controlRoll+=axis(state,"RollRight","RollLeft")*authority end
			controlCount+=1
		end
	end

	if controlCount>0 and primary.AssemblyLinearVelocity.Magnitude>6 then
		local effectiveness=math.clamp(primary.AssemblyLinearVelocity.Magnitude/70,.12,1.4)
		local localAngular=primary.CFrame:VectorToObjectSpace(primary.AssemblyAngularVelocity)
		local target=Vector3.new(controlPitch*.85*effectiveness,controlYaw*.75*effectiveness,-controlRoll*.95*effectiveness)
		local blended=localAngular:Lerp(target,math.clamp(dt*4.5,0,1))
		primary.AssemblyAngularVelocity=primary.CFrame:VectorToWorldSpace(blended)
	end
end

function Aero:Start()
	RunService.Heartbeat:Connect(function(dt)
		self._accumulator+=dt
		if self._accumulator<1/30 then return end
		local step=self._accumulator; self._accumulator=0
		local assemblies=Workspace:FindFirstChild("MechAssemblies")
		if not assemblies then return end
		for _, model in ipairs(assemblies:GetChildren()) do if model:IsA("Model") then self:_stepModel(model,step) end end
	end)
end

return Aero
