--!nonstrict

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local UserInputService =
	game:GetService("UserInputService")

local RunService =
	game:GetService("RunService")

--------------------------------------------------
-- PLAYER
--------------------------------------------------

local player =
	Players.LocalPlayer

if not player then
	error(
		"[GOD MACHINES] LocalPlayer unavailable"
	)
end

local playerGui =
	player:WaitForChild("PlayerGui")

local mouse =
	player:GetMouse()

--------------------------------------------------
-- MODULES
--------------------------------------------------

local BuildUI =
	require(script.Parent.BuildUI)

local BuildPreview =
	require(script.Parent.BuildPreview)

local BuildInput =
	require(script.Parent.BuildInput)

--------------------------------------------------
-- FRAMEWORK
--------------------------------------------------

local framework =
	ReplicatedStorage:WaitForChild(
		"MechFramework"
	)

local Shared =
	framework:WaitForChild(
		"Shared"
	)

local Remotes =
	framework:WaitForChild(
		"Remotes"
	)

local Functions =
	Remotes:WaitForChild(
		"Functions"
	)

local BuildMath =
	require(
		Shared:WaitForChild(
			"BuildMath"
		)
	)

local remote =
	Functions:WaitForChild(
		"RequestBuildAction"
	)

if not remote:IsA("RemoteFunction") then
	error(
		"RequestBuildAction must be RemoteFunction"
	)
end

--------------------------------------------------
-- PART CONTENT
--------------------------------------------------

local PARTS = {

	{
		Id =
			"StructuralFrame",

		DisplayName =
			"STRUCTURAL FRAME",

		ShortName =
			"FRAME",

		Slot = 1,
	},

	{
		Id =
			"SmallReactor",

		DisplayName =
			"SMALL REACTOR",

		ShortName =
			"REACTOR",

		Slot = 2,
	},

	{
		Id =
			"Autocannon",

		DisplayName =
			"AUTOCANNON",

		ShortName =
			"CANNON",

		Slot = 3,
	},
}

--------------------------------------------------
-- STATE
--------------------------------------------------

local buildMode =
	false

local selectedPart =
	PARTS[1].Id

local mechId =
	nil

local definitions =
	{}

local statusLockUntil =
	0

--------------------------------------------------
-- UI / PREVIEW
--------------------------------------------------

local ui =
	BuildUI.new(playerGui)

local preview =
	BuildPreview.new(
		mouse,
		BuildMath
	)

--------------------------------------------------
-- STATUS
--------------------------------------------------

local function status(
	text,
	tone,
	duration
)
	ui:SetStatus(
		text,
		tone
	)

	statusLockUntil =
		os.clock()
		+ (duration or 0)
end

--------------------------------------------------
-- LOAD DEFINITIONS
--------------------------------------------------
local function loadDefinition(partType)
	local cached = definitions[partType]
	if cached then
		return cached
	end

	print("[GOD MACHINES] Definition request ->", partType)
	local success, result = remote:InvokeServer({
		Action = "Definition",
		PartType = partType,
	})
	print("[GOD MACHINES] Definition response <-", partType, success, result ~= nil)

	if not success then
		warn(
			"[GOD MACHINES] Missing definition:",
			partType,
			result
		)
		return nil
	end

	definitions[partType] = result
	return result
end

--------------------------------------------------
-- SELECT PART
--------------------------------------------------
local function selectPart(partType)
	local definition =
		loadDefinition(
			partType
		)

	if not definition then
		status(
			"PART UNAVAILABLE",
			"bad",
			1
		)

		return
	end

	selectedPart =
		partType

	ui:SetSelectedPart(
		partType
	)

	ui:SetInspector(
		partType,
		definition
	)

	preview:SetDefinition(
		definition
	)

	status(
		"SELECTED " .. partType,
		"good",
		0.5
	)
end

--------------------------------------------------
-- BUILD MODE
--------------------------------------------------

local function toggleBuildMode()
	buildMode =
		not buildMode

	ui:SetBuildMode(
		buildMode
	)

	preview:SetEnabled(
		buildMode
	)

	input:SetActive(
		buildMode
	)

	if buildMode then
		selectPart(
			selectedPart
		)

		status(
			"BUILD MODE ONLINE",
			"good",
			0.7
		)
	end
end

--------------------------------------------------
-- PLACE
--------------------------------------------------

local function placePart()
	if not buildMode then
		return
	end

	local data =
		preview:GetPlacement()

	local requestMechId =
		data.TargetMechId
		or mechId

	local success, result =
		remote:InvokeServer({

			Action =
			"Place",

			MechId =
			requestMechId,

			PartType =
			selectedPart,

			Transform =
			data.Transform,

			TargetComponentId =
			data.TargetComponentId,

			TargetNode =
			data.TargetNode,

			SourceNode =
			data.SourceNode,

			Rotation =
			data.Rotation,
		})

	--------------------------------------------------
	-- SUCCESS
	--------------------------------------------------

	if success then
		if
			type(result) == "table"
			and result.MechId
		then
			mechId =
				result.MechId
		end

		status(
			"COMPONENT INSTALLED",
			"good",
			0.65
		)

		return
	end

	--------------------------------------------------
	-- FAILURE
	--------------------------------------------------

	preview:Reject()

	status(
		tostring(result),
		"bad",
		1
	)
end

--------------------------------------------------
-- REMOVE
--------------------------------------------------

local function removePart()
	local target =
		mouse.Target

	if not target then
		return
	end

	local targetMech =
		target:GetAttribute(
			"MechId"
		)

	local component =
		target:GetAttribute(
			"ComponentId"
		)

	if
		type(targetMech) ~= "string"
		or type(component) ~= "string"
	then
		status(
			"NO COMPONENT SELECTED",
			"bad",
			0.7
		)

		return
	end

	local success, result =
		remote:InvokeServer({

			Action =
			"Remove",

			MechId =
			targetMech,

			ComponentId =
			component,
		})

	if success then
		status(
			"COMPONENT REMOVED",
			"good",
			0.6
		)
	else
		status(
			tostring(result),
			"bad",
			1
		)
	end
end

--------------------------------------------------
-- UNDO
--------------------------------------------------

local function undo()
	local success, result =
		remote:InvokeServer({
			Action = "Undo",
		})

	if success then
		if
			type(result) == "table"
			and result.MechId
		then
			mechId =
				result.MechId
		end

		status(
			"UNDO",
			"good",
			0.5
		)
	else
		status(
			tostring(result),
			"bad",
			0.7
		)
	end
end

--------------------------------------------------
-- REDO
--------------------------------------------------

local function redo()
	local success, result =
		remote:InvokeServer({
			Action = "Redo",
		})

	if success then
		if
			type(result) == "table"
			and result.MechId
		then
			mechId =
				result.MechId
		end

		status(
			"REDO",
			"good",
			0.5
		)
	else
		status(
			tostring(result),
			"bad",
			0.7
		)
	end
end

--------------------------------------------------
-- INPUT
--------------------------------------------------

input =
	BuildInput.new(
		UserInputService,
		{

			Toggle =
			toggleBuildMode,

			Rotate =
			function()
				preview:Rotate()

				status(
					"ROTATED 90°",
					nil,
					0.25
				)
			end,

			Place =
			placePart,

			Remove =
			removePart,

			Undo =
			undo,

			Redo =
			redo,

			SelectSlot =
			function(slot)
				local part =
				PARTS[slot]

				if part then
					selectPart(
						part.Id
					)
				end
			end,
		}
	)

--------------------------------------------------
-- UI PART BUTTONS
--------------------------------------------------

ui:SetParts(
	PARTS,
	function(partType)
		selectPart(
			partType
		)
	end
)

--------------------------------------------------
-- DEFAULT
--------------------------------------------------

selectPart(
	selectedPart
)

ui:SetBuildMode(false)

preview:SetEnabled(false)

--------------------------------------------------
-- PREVIEW LOOP
--------------------------------------------------

RunService.RenderStepped:Connect(
	function()

		if not buildMode then
			return
		end

		local state =
			preview:Update()

		--------------------------------------------------
		-- DON'T OVERWRITE TEMPORARY MESSAGES
		--------------------------------------------------

		if
			os.clock()
			< statusLockUntil
		then
			return
		end

		if state == "SNAP" then
			ui:SetStatus(
				"ATTACHMENT READY",
				"good"
			)

		elseif state == "FREE" then
			ui:SetStatus(
				"FREE PLACEMENT",
				nil
			)

		elseif state == "REJECTED" then
			ui:SetStatus(
				"PLACEMENT REJECTED",
				"bad"
			)
		end
	end
)

print(
	"[GOD MACHINES] Builder initialized"
)