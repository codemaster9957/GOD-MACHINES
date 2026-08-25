--!nonstrict

local BuildPreview = {}
BuildPreview.__index = BuildPreview

local GREEN = Color3.fromRGB(65, 255, 130)
local ORANGE = Color3.fromRGB(255, 184, 55)
local RED = Color3.fromRGB(255, 65, 65)

local function splitCompatibility(value)
	local out = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	for token in string.gmatch(value, "[^,]+") do
		table.insert(out, token)
	end
	return out
end

local function freeTransform(hitPosition, size, turns)
	return CFrame.new(hitPosition + Vector3.new(0, size.Y / 2, 0))
		* CFrame.Angles(0, math.rad((turns % 4) * 90), 0)
end

function BuildPreview.new(mouse, BuildMath)
	local self = setmetatable({}, BuildPreview)
	self.Mouse = mouse
	self.BuildMath = BuildMath
	self.Enabled = false
	self.Definition = nil
	self.Ghost = nil
	self.Turns = 0
	self.TargetPart = nil
	self.TargetNode = nil
	self.SourceNode = nil
	self.PreviewCFrame = CFrame.new()
	self.RejectedUntil = 0
	self.LastState = "OFF"
	return self
end

function BuildPreview:_destroyGhost()
	if self.Ghost then
		self.Ghost:Destroy()
		self.Ghost = nil
	end
end

function BuildPreview:_createGhost()
	self:_destroyGhost()
	if not self.Definition or typeof(self.Definition.Size) ~= "Vector3" then
		return
	end

	local ghost = Instance.new("Part")
	ghost.Name = "GodMachinesBuildGhost"
	ghost.Size = self.Definition.Size
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.CastShadow = false
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.ForceField
	ghost.Parent = workspace
	self.Ghost = ghost
end

function BuildPreview:SetEnabled(enabled)
	self.Enabled = enabled == true
	if self.Enabled then
		if self.Definition then
			self:_createGhost()
		end
	else
		self:_destroyGhost()
		self.TargetPart = nil
		self.TargetNode = nil
		self.SourceNode = nil
		self.LastState = "OFF"
	end
end

function BuildPreview:SetDefinition(definition)
	if type(definition) ~= "table" or typeof(definition.Size) ~= "Vector3" then
		self.Definition = nil
		self:_destroyGhost()
		return false
	end
	self.Definition = definition
	self.Turns = 0
	if self.Enabled then
		self:_createGhost()
	end
	return true
end

function BuildPreview:Rotate()
	self.Turns = (self.Turns + 1) % 4
end

function BuildPreview:_targetNodeData(attachment)
	local accepts = splitCompatibility(attachment:GetAttribute("Compatibility"))
	if #accepts == 0 then
		accepts = { "*" }
	end
	return {
		Name = attachment.Name,
		Type = tostring(attachment:GetAttribute("NodeType") or ""),
		Transform = attachment.CFrame,
		Accepts = accepts,
		CompatibleWith = accepts,
	}
end

function BuildPreview:_findCompatiblePair(part, hitPosition)
	if not self.Definition or type(self.Definition.AttachmentNodes) ~= "table" then
		return nil, nil
	end

	local candidates = {}
	for _, object in ipairs(part:GetChildren()) do
		if object:IsA("Attachment") and object:GetAttribute("Occupied") ~= true then
			table.insert(candidates, object)
		end
	end

	table.sort(candidates, function(a, b)
		return (a.WorldPosition - hitPosition).Magnitude < (b.WorldPosition - hitPosition).Magnitude
	end)

	for _, attachment in ipairs(candidates) do
		local targetData = self:_targetNodeData(attachment)
		for _, source in ipairs(self.Definition.AttachmentNodes) do
			if type(source) == "table" and type(source.Name) == "string" and typeof(source.Transform) == "CFrame" then
				local ok, compatible = pcall(self.BuildMath.Compatible, targetData, source)
				if ok and compatible then
					return attachment, source
				end
			end
		end
	end

	return nil, nil
end

function BuildPreview:Update(activeMechId)
	if not self.Enabled or not self.Ghost or not self.Definition then
		self.LastState = "OFF"
		return self.LastState
	end

	self.TargetPart = nil
	self.TargetNode = nil
	self.SourceNode = nil

	local hitPosition = self.Mouse.Hit.Position
	local candidate = self.Mouse.Target
	self.PreviewCFrame = freeTransform(hitPosition, self.Definition.Size, self.Turns)

	if candidate and candidate:GetAttribute("ComponentId") ~= nil then
		local candidateMechId = candidate:GetAttribute("MechId")

		if type(activeMechId) ~= "string" then
			self.Ghost.CFrame = self.PreviewCFrame
			self.Ghost.Color = RED
			self.LastState = "START_ON_GROUND"
			return self.LastState
		end

		if candidateMechId ~= activeMechId then
			self.Ghost.CFrame = self.PreviewCFrame
			self.Ghost.Color = RED
			self.LastState = "OTHER_MECH"
			return self.LastState
		end

		local attachment, source = self:_findCompatiblePair(candidate, hitPosition)
		if attachment and source then
			local ok, snapped = pcall(
				self.BuildMath.Snap,
				candidate.CFrame,
				attachment.CFrame,
				source.Transform,
				self.Turns
			)
			if ok and typeof(snapped) == "CFrame" then
				self.TargetPart = candidate
				self.TargetNode = attachment.Name
				self.SourceNode = source.Name
				self.PreviewCFrame = snapped
				self.Ghost.CFrame = snapped
				self.Ghost.Color = GREEN
				self.LastState = "SNAP"
				return self.LastState
			end
		end

		self.Ghost.CFrame = self.PreviewCFrame
		self.Ghost.Color = RED
		self.LastState = "NO_COMPATIBLE_NODE"
		return self.LastState
	end

	self.Ghost.CFrame = self.PreviewCFrame

	if os.clock() < self.RejectedUntil then
		self.Ghost.Color = RED
		self.LastState = "REJECTED"
		return self.LastState
	end

	if type(activeMechId) == "string" then
		self.Ghost.Color = RED
		self.LastState = "ATTACHMENT_REQUIRED"
		return self.LastState
	end

	self.Ghost.Color = ORANGE
	self.LastState = "FREE"
	return self.LastState
end

function BuildPreview:Reject()
	self.RejectedUntil = os.clock() + 0.35
end

function BuildPreview:GetPlacement(activeMechId)
	if type(activeMechId) == "string" then
		if self.LastState ~= "SNAP" or not self.TargetPart then
			return nil, self.LastState
		end
	else
		if self.LastState ~= "FREE" then
			return nil, self.LastState
		end
	end

	local targetComponentId = nil
	local targetMechId = nil
	if self.TargetPart then
		targetComponentId = self.TargetPart:GetAttribute("ComponentId")
		targetMechId = self.TargetPart:GetAttribute("MechId")
	end

	return {
		Transform = self.PreviewCFrame,
		Rotation = self.Turns,
		TargetComponentId = targetComponentId,
		TargetMechId = targetMechId,
		TargetNode = self.TargetNode,
		SourceNode = self.SourceNode,
	}, nil
end

function BuildPreview:Destroy()
	self:_destroyGhost()
	self.Enabled = false
	self.LastState = "OFF"
end

return BuildPreview
