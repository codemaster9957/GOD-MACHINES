--!strict
-- Deterministic procedural renderer shared by runtime machines and client previews.

local Renderer = {}

local PREVIEW_COLORS = {
	FREE = Color3.fromRGB(255, 184, 55),
	SNAP = Color3.fromRGB(65, 255, 130),
	INVALID = Color3.fromRGB(255, 65, 65),
}

local function safeMaterial(value: any, fallback: Enum.Material): Enum.Material
	if typeof(value) == "EnumItem" and value.EnumType == Enum.Material then
		return value
	end
	if type(value) == "string" then
		local ok, result = pcall(function()
			return (Enum.Material :: any)[value]
		end)
		if ok and typeof(result) == "EnumItem" then
			return result
		end
	end
	return fallback
end

local function regionColor(definition: any, paint: any, region: string): Color3
	if type(paint) == "table" and typeof(paint[region]) == "Color3" then
		return paint[region]
	end
	local defaults = definition.PaintDefaults
	if type(defaults) == "table" and typeof(defaults[region]) == "Color3" then
		return defaults[region]
	end
	if type(defaults) == "table" and typeof(defaults.Primary) == "Color3" then
		return defaults.Primary
	end
	return Color3.fromRGB(105, 110, 116)
end

local function makeVisual(kind: string): BasePart
	if kind == "Wedge" then
		return Instance.new("WedgePart")
	elseif kind == "CornerWedge" then
		return Instance.new("CornerWedgePart")
	elseif kind == "Seat" then
		return Instance.new("Seat")
	elseif kind == "VehicleSeat" then
		return Instance.new("VehicleSeat")
	end
	local part = Instance.new("Part")
	if kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	return part
end

local function configureVehicleSeat(part: BasePart)
	if part:IsA("VehicleSeat") then
		part.MaxSpeed = 0
		part.Torque = 0
		part.TurnSpeed = 0
	end
end

local function applyIdentity(instance: Instance, attributes: any)
	for key, value in pairs(attributes or {}) do
		if type(key) == "string" then
			local valueType = typeof(value)
			if valueType == "string" or valueType == "number" or valueType == "boolean" or valueType == "Color3" or valueType == "Vector3" or valueType == "CFrame" then
				instance:SetAttribute(key, value)
			end
		end
	end
end

function Renderer.Render(definition: any, options: any?): (Model, BasePart)
	assert(type(definition) == "table" and typeof(definition.Size) == "Vector3", "PartRenderer requires a valid definition")
	options = options or {}
	local mode = if options.Mode == "Preview" then "Preview" else "Runtime"
	local transform = if typeof(options.CFrame) == "CFrame" then options.CFrame else CFrame.identity
	local paint = options.Paint

	local model = Instance.new("Model")
	model.Name = tostring(options.Name or definition.Id or "Component")
	model:SetAttribute("PartType", tostring(definition.Id or options.PartType or "Unknown"))
	model:SetAttribute("RenderMode", mode)
	applyIdentity(model, options.Attributes)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = definition.Size
	root.CFrame = transform
	root.Transparency = 1
	root.Material = Enum.Material.SmoothPlastic
	root.CastShadow = false
	root.Anchored = mode == "Preview" or options.Anchored == true
	root.CanCollide = mode == "Runtime"
	root.CanTouch = mode == "Runtime"
	root.CanQuery = mode == "Runtime"
	root.Massless = mode == "Preview"
	root:SetAttribute("ComponentRoot", true)
	root:SetAttribute("PartType", tostring(definition.Id or options.PartType or "Unknown"))
	applyIdentity(root, options.Attributes)
	root.Parent = model
	model.PrimaryPart = root

	for _, node in ipairs(definition.AttachmentNodes or {}) do
		if type(node) == "table" and type(node.Name) == "string" and typeof(node.Transform) == "CFrame" then
			local attachment = Instance.new("Attachment")
			attachment.Name = node.Name
			attachment.CFrame = node.Transform
			attachment:SetAttribute("BuildNode", true)
			attachment:SetAttribute("NodeType", tostring(node.Type or ""))
			local compatibility = {}
			for _, compatible in ipairs(node.CompatibleWith or node.Accepts or {}) do
				table.insert(compatibility, tostring(compatible))
			end
			attachment:SetAttribute("Compatibility", table.concat(compatibility, ","))
			attachment:SetAttribute("Occupied", node.OccupiedBy ~= nil)
			attachment:SetAttribute("OccupiedBy", if node.OccupiedBy ~= nil then tostring(node.OccupiedBy) else "")
			attachment.Parent = root
		end
	end

	local visuals = Instance.new("Folder")
	visuals.Name = "Visuals"
	visuals.Parent = model

	for _, item in ipairs(definition.Geometry or {}) do
		local visual = makeVisual(tostring(item.Kind or "Block"))
		visual.Name = tostring(item.Name or "Visual")
		visual.Size = item.Size
		visual.CFrame = transform * item.CFrame
		visual.Color = regionColor(definition, paint, tostring(item.Region or "Primary"))
		visual.Material = safeMaterial(item.Material, Enum.Material.Metal)
		visual.Transparency = tonumber(item.Transparency) or 0
		visual.CastShadow = mode == "Runtime" and visual.Transparency < 0.95
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = (mode == "Runtime" and (visual:IsA("Seat") or visual:IsA("VehicleSeat")))
		visual.Massless = true
		visual.Anchored = mode == "Preview"
		visual:SetAttribute("GMVisual", true)
		visual:SetAttribute("PaintRegion", tostring(item.Region or "Primary"))
		visual:SetAttribute("BaseColor", visual.Color)
		visual:SetAttribute("Role", tostring(item.Role or ""))
		applyIdentity(visual, options.Attributes)
		configureVehicleSeat(visual)
		visual.Parent = visuals

		if mode == "Runtime" then
			if type(item.Role) == "string" and item.Role ~= "" and string.find(item.Role, "Spinner") then
				local motor = Instance.new("Motor6D")
				motor.Name = item.Role .. "Motor"
				motor.Part0 = root
				motor.Part1 = visual
				motor.C0 = item.CFrame
				motor.C1 = CFrame.identity
				motor:SetAttribute("Role", item.Role)
				motor.Parent = root
			else
				local weld = Instance.new("WeldConstraint")
				weld.Name = "VisualWeld_" .. visual.Name
				weld.Part0 = root
				weld.Part1 = visual
				weld.Parent = root
			end
		else
			visual.Transparency = math.max(visual.Transparency, 0.35)
		end
	end

	local parent = options.Parent
	if typeof(parent) == "Instance" then
		model.Parent = parent
	end
	return model, root
end

function Renderer.ApplyPaint(model: Model, definition: any, paint: any)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("GMVisual") == true then
			local region = tostring(descendant:GetAttribute("PaintRegion") or "Primary")
			local color = regionColor(definition, paint, region)
			descendant.Color = color
			descendant:SetAttribute("BaseColor", color)
			if type(paint) == "table" and paint.Material ~= nil and region ~= "Glass" then
				descendant.Material = safeMaterial(paint.Material, descendant.Material)
			end
		end
	end
end

function Renderer.SetPreviewState(model: Model, state: string)
	local tint = PREVIEW_COLORS[state] or PREVIEW_COLORS.INVALID
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("GMVisual") == true then
			local base = descendant:GetAttribute("BaseColor")
			if typeof(base) ~= "Color3" then
				base = descendant.Color
			end
			descendant.Color = (base :: Color3):Lerp(tint, 0.58)
			descendant.Transparency = math.max(descendant.Transparency, 0.38)
		end
	end
end

function Renderer.SetSpinner(model: Model, role: string, angle: number)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant:GetAttribute("Role") == role then
			descendant.Transform = CFrame.Angles(angle, 0, 0)
		end
	end
end

function Renderer.SetAllSpinners(model: Model, angle: number)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and type(descendant:GetAttribute("Role")) == "string" then
			descendant.Transform = CFrame.Angles(angle, 0, 0)
		end
	end
end

return Renderer
