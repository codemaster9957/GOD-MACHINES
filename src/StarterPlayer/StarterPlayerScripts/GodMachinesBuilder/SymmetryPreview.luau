--!nonstrict
-- Client-only mirrored placement visualization. Server recomputes symmetry authoritatively.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared")
local BuildMath = require(Shared:WaitForChild("BuildMath"))
local PartRenderer = require(Shared:WaitForChild("PartRenderer"))

local SymmetryPreview = {}
SymmetryPreview.__index = SymmetryPreview

local function activeMechModel(mechId)
	if type(mechId) ~= "string" or mechId == "" then return nil end
	local assemblies = workspace:FindFirstChild("MechAssemblies")
	local model = assemblies and assemblies:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end

function SymmetryPreview.new()
	local self = setmetatable({}, SymmetryPreview)
	self.Enabled = false
	self.Ghost = nil
	self.Definition = nil
	self.Paint = nil
	self.MirrorX = false
	self.LastTransform = nil
	return self
end

function SymmetryPreview:_destroyGhost()
	if self.Ghost then self.Ghost:Destroy() end
	self.Ghost = nil
end

function SymmetryPreview:SetEnabled(enabled)
	self.Enabled = enabled == true
	if not self.Enabled then self:_destroyGhost() end
	return self.Enabled
end

function SymmetryPreview:Toggle()
	return self:SetEnabled(not self.Enabled)
end

function SymmetryPreview:Update(definition, paint, mirrorX, sourceTransform, mechId, validState)
	if not self.Enabled or type(definition) ~= "table" or typeof(sourceTransform) ~= "CFrame" then
		self:_destroyGhost()
		return nil
	end
	local mech = activeMechModel(mechId)
	if not mech then
		self:_destroyGhost()
		return nil
	end
	local pivot = mech:GetPivot()
	local mirrored = BuildMath.MirrorWorldAcrossLocalX(pivot, sourceTransform)
	local appearanceChanged = self.Definition ~= definition or self.Paint ~= paint or self.MirrorX ~= (mirrorX == true)
	if not self.Ghost or appearanceChanged then
		self:_destroyGhost()
		local model = PartRenderer.Render(definition, {
			Mode = "Preview",
			Name = "GodMachinesSymmetryGhost",
			CFrame = mirrored,
			Paint = paint or definition.PaintDefaults,
			MirrorX = not (mirrorX == true),
			Parent = workspace,
		})
		self.Ghost = model
		self.Definition = definition
		self.Paint = paint
		self.MirrorX = mirrorX == true
	else
		self.Ghost:PivotTo(mirrored)
	end
	self.LastTransform = mirrored
	if self.Ghost then
		PartRenderer.SetPreviewState(self.Ghost, validState == "SNAP" and "SNAP" or "INVALID")
	end
	return mirrored
end

function SymmetryPreview:GetTransform()
	return self.LastTransform
end

function SymmetryPreview:Destroy()
	self:_destroyGhost()
	self.Enabled = false
end

return SymmetryPreview
