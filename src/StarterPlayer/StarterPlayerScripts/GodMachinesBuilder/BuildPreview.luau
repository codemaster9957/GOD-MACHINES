--!nonstrict

local BuildPreview = {}
BuildPreview.__index = BuildPreview

local GREEN =
	Color3.fromRGB(65, 255, 130)

local ORANGE =
	Color3.fromRGB(255, 184, 55)

local RED =
	Color3.fromRGB(255, 65, 65)

--------------------------------------------------
-- CREATE
--------------------------------------------------

function BuildPreview.new(mouse, BuildMath)
	local self =
		setmetatable(
			{},
			BuildPreview
		)

	self.Mouse = mouse
	self.BuildMath = BuildMath

	self.Enabled = false

	self.Definition = nil
	self.Ghost = nil

	self.Turns = 0

	self.TargetPart = nil
	self.TargetNode = nil
	self.SourceNode = nil

	self.PreviewCFrame =
		CFrame.new()

	self.RejectedUntil = 0

	return self
end

--------------------------------------------------
-- CREATE GHOST
--------------------------------------------------

function BuildPreview:_createGhost()
	if self.Ghost then
		self.Ghost:Destroy()
	end

	if not self.Definition then
		return
	end

	local ghost =
		Instance.new("Part")

	ghost.Name =
		"GodMachinesBuildGhost"

	ghost.Size =
		self.Definition.Size

	ghost.Anchored = true

	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false

	ghost.CastShadow = false

	ghost.Transparency = 0.5

	ghost.Material =
		Enum.Material.ForceField

	ghost.Parent =
		workspace

	self.Ghost = ghost
end

--------------------------------------------------
-- ENABLE
--------------------------------------------------

function BuildPreview:SetEnabled(enabled)
	self.Enabled = enabled

	if enabled then
		if self.Definition then
			self:_createGhost()
		end
	else
		if self.Ghost then
			self.Ghost:Destroy()
			self.Ghost = nil
		end
	end
end

--------------------------------------------------
-- DEFINITION
--------------------------------------------------

function BuildPreview:SetDefinition(definition)
	self.Definition =
		definition

	self.Turns = 0

	if self.Enabled then
		self:_createGhost()
	end
end

--------------------------------------------------
-- ROTATE
--------------------------------------------------

function BuildPreview:Rotate()
	self.Turns =
		(self.Turns + 1) % 4
end

--------------------------------------------------
-- FIND NODE
--------------------------------------------------

local function nearestNode(part, hit)
	local best = nil
	local bestDistance =
		math.huge

	for _, object in ipairs(
		part:GetChildren()
		) do
		if
			object:IsA("Attachment")
			and object:GetAttribute("Occupied") ~= true
		then
			local distance =
				(
					object.WorldPosition
					- hit
				).Magnitude

			if distance < bestDistance then
				best =
					object

				bestDistance =
					distance
			end
		end
	end

	return best
end

--------------------------------------------------
-- SOURCE NODE
--------------------------------------------------

function BuildPreview:_sourceNode()
	if not self.Definition then
		return nil
	end

	local nodes =
		self.Definition.AttachmentNodes

	if type(nodes) ~= "table" then
		return nil
	end

	return nodes[1]
end

--------------------------------------------------
-- UPDATE
--------------------------------------------------

function BuildPreview:Update()
	if
		not self.Enabled
		or not self.Ghost
		or not self.Definition
	then
		return "OFF"
	end

	self.TargetPart = nil
	self.TargetNode = nil
	self.SourceNode = nil

	local hit =
		self.Mouse.Hit.Position

	local candidate =
		self.Mouse.Target

	--------------------------------------------------
	-- SNAP TO COMPONENT
	--------------------------------------------------

	if
		candidate
		and candidate:GetAttribute(
			"ComponentId"
		)
	then
		local attachment =
			nearestNode(
				candidate,
				hit
			)

		local source =
			self:_sourceNode()

		if attachment and source then

			self.TargetPart =
				candidate

			self.TargetNode =
				attachment.Name

			self.SourceNode =
				source.Name

			self.PreviewCFrame =
				self.BuildMath.Snap(
					candidate.CFrame,
					attachment.CFrame,
					source.Transform,
					self.Turns
				)
		end
	end

	--------------------------------------------------
	-- FREE PLACEMENT
	--------------------------------------------------

	if not self.TargetPart then
		self.PreviewCFrame =
			CFrame.new(
				hit
				+ Vector3.new(
					0,
					self.Definition.Size.Y / 2,
					0
				)
			)

		self.PreviewCFrame *=
			CFrame.Angles(
				0,
				math.rad(
					self.Turns * 90
				),
				0
			)
	end

	self.Ghost.CFrame =
		self.PreviewCFrame

	--------------------------------------------------
	-- COLOR
	--------------------------------------------------

	if os.clock() < self.RejectedUntil then
		self.Ghost.Color = RED
		return "REJECTED"
	end

	if self.TargetPart then
		self.Ghost.Color = GREEN
		return "SNAP"
	end

	self.Ghost.Color = ORANGE
	return "FREE"
end

--------------------------------------------------
-- REJECTION
--------------------------------------------------

function BuildPreview:Reject()
	self.RejectedUntil =
		os.clock() + 0.35
end

--------------------------------------------------
-- PLACEMENT DATA
--------------------------------------------------

function BuildPreview:GetPlacement()
	local targetComponentId = nil
	local targetMechId = nil

	if self.TargetPart then
		targetComponentId =
			self.TargetPart:GetAttribute(
				"ComponentId"
			)

		targetMechId =
			self.TargetPart:GetAttribute(
				"MechId"
			)
	end

	return {
		Transform =
			self.PreviewCFrame,

		Rotation =
			self.Turns,

		TargetComponentId =
			targetComponentId,

		TargetMechId =
			targetMechId,

		TargetNode =
			self.TargetNode,

		SourceNode =
			self.SourceNode,
	}
end

return BuildPreview