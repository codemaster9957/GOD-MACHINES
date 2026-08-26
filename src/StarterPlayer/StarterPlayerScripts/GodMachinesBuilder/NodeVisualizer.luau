--!nonstrict
-- Client-only attachment-node markers. They never participate in physics or server authority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MechFramework"):WaitForChild("Shared")
local BuildMath = require(Shared:WaitForChild("BuildMath"))
local PartCatalog = require(Shared:WaitForChild("PartCatalog"))

local NodeVisualizer = {}
NodeVisualizer.__index = NodeVisualizer

local FREE = Color3.fromRGB(77, 232, 139)
local OCCUPIED = Color3.fromRGB(255, 181, 54)
local INCOMPATIBLE = Color3.fromRGB(120, 127, 135)

local function splitCompatibility(value)
	local out = {}
	if type(value) ~= "string" or value == "" then return out end
	for token in string.gmatch(value, "[^,]+") do table.insert(out, token) end
	return out
end

local function targetNodeData(attachment)
	local accepts = splitCompatibility(attachment:GetAttribute("Compatibility"))
	if #accepts == 0 then accepts = {"*"} end
	return {
		Name = attachment.Name,
		Type = tostring(attachment:GetAttribute("NodeType") or ""),
		Transform = attachment.CFrame,
		Accepts = accepts,
		CompatibleWith = accepts,
	}
end

local function selectedSourceNodes()
	local ghost = workspace:FindFirstChild("GodMachinesBuildGhost")
	if not ghost or not ghost:IsA("Model") then return nil end
	local partType = ghost:GetAttribute("PartType")
	if type(partType) ~= "string" or partType == "" then return nil end
	local definition = PartCatalog.Get(partType)
	if not definition then return nil end
	return BuildMath.AttachmentNodes(definition, ghost:GetAttribute("MirrorX") == true)
end

function NodeVisualizer.new()
	local self = setmetatable({}, NodeVisualizer)
	self.Enabled = true
	self.MechId = nil
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "GodMachinesNodeMarkers"
	-- Keep markers independent of camera replacement/reset events.
	self.Folder.Parent = workspace
	self._markers = {}
	return self
end

function NodeVisualizer:SetEnabled(enabled)
	self.Enabled = enabled == true
	if not self.Enabled then self:Clear() end
end

function NodeVisualizer:SetMech(mechId)
	if self.MechId == mechId then return end
	self.MechId = mechId
	self:Clear()
end

function NodeVisualizer:Clear()
	for attachment, marker in pairs(self._markers) do
		if marker then marker:Destroy() end
		self._markers[attachment] = nil
	end
end

local function findModel(mechId)
	if type(mechId) ~= "string" then return nil end
	local assemblies = workspace:FindFirstChild("MechAssemblies")
	local model = assemblies and assemblies:FindFirstChild(mechId)
	return if model and model:IsA("Model") then model else nil
end

function NodeVisualizer:_makeMarker(attachment)
	local marker = Instance.new("Part")
	marker.Name = "BuildNodeMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.34, 0.34, 0.34)
	marker.Material = Enum.Material.Neon
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Transparency = 0.12
	marker.Parent = self.Folder
	self._markers[attachment] = marker
	return marker
end

function NodeVisualizer:Update()
	if not self.Enabled or type(self.MechId) ~= "string" then return end
	local model = findModel(self.MechId)
	if not model then self:Clear(); return end

	local sourceNodes = selectedSourceNodes()
	local live = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant:GetAttribute("BuildNode") == true then
			live[descendant] = true
			local marker = self._markers[descendant] or self:_makeMarker(descendant)
			marker.CFrame = descendant.WorldCFrame
			if descendant:GetAttribute("Occupied") == true then
				marker.Color = OCCUPIED
				marker.Size = Vector3.new(0.26, 0.26, 0.26)
				marker.Transparency = 0.55
			else
				local compatible = false
				if sourceNodes then
					local ok, source = pcall(BuildMath.BestCompatibleSource, targetNodeData(descendant), sourceNodes)
					compatible = ok and source ~= nil
				end
				if compatible then
					marker.Color = FREE
					marker.Size = Vector3.new(0.36, 0.36, 0.36)
					marker.Transparency = 0.08
				else
					marker.Color = INCOMPATIBLE
					marker.Size = Vector3.new(0.28, 0.28, 0.28)
					marker.Transparency = 0.35
				end
			end
		end
	end
	for attachment, marker in pairs(self._markers) do
		if not live[attachment] or attachment.Parent == nil then
			marker:Destroy()
			self._markers[attachment] = nil
		end
	end
end

function NodeVisualizer:Destroy()
	self:Clear()
	if self.Folder then self.Folder:Destroy() end
end

return NodeVisualizer
