--!nonstrict
-- Client-only selection state/visuals for edit mode. Server remains authoritative for every group mutation.

local BuildSelection = {}
BuildSelection.__index = BuildSelection

local MAX_VISUAL_SELECTION = 250

local function resolveComponentModel(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and type(current:GetAttribute("ComponentId")) == "string" then
			return current
		end
		current = current.Parent
	end
	return nil
end

function BuildSelection.new()
	local self = setmetatable({}, BuildSelection)
	self.MechId = nil
	self.Selected = {}
	self.Highlights = {}
	return self
end

function BuildSelection:SetMech(mechId)
	local normalized = if type(mechId) == "string" and mechId ~= "" then mechId else nil
	if normalized ~= self.MechId then
		self:Clear()
		self.MechId = normalized
	end
end

function BuildSelection:_destroyHighlight(componentId)
	local highlight = self.Highlights[componentId]
	if highlight then highlight:Destroy() end
	self.Highlights[componentId] = nil
end

function BuildSelection:_findComponentModel(componentId)
	if not self.MechId then return nil end
	local assemblies = workspace:FindFirstChild("MechAssemblies")
	local mech = assemblies and assemblies:FindFirstChild(self.MechId)
	if not mech or not mech:IsA("Model") then return nil end
	local component = mech:FindFirstChild(componentId)
	return if component and component:IsA("Model") then component else nil
end

function BuildSelection:_show(componentId)
	if self.Highlights[componentId] then return end
	if self:Count() > MAX_VISUAL_SELECTION then return end
	local component = self:_findComponentModel(componentId)
	if not component then return end
	local highlight = Instance.new("Highlight")
	highlight.Name = "GMSelection_" .. componentId
	highlight.Adornee = component
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 174, 52)
	highlight.FillTransparency = 0.78
	highlight.OutlineColor = Color3.fromRGB(255, 226, 154)
	highlight.OutlineTransparency = 0.06
	highlight.Parent = component
	self.Highlights[componentId] = highlight
end

function BuildSelection:ToggleFromInstance(instance)
	local component = resolveComponentModel(instance)
	if not component then return false end
	local componentId = component:GetAttribute("ComponentId")
	local mechId = component:GetAttribute("MechId")
	if type(componentId) ~= "string" or mechId ~= self.MechId then return false end
	return self:Toggle(componentId)
end

function BuildSelection:Toggle(componentId)
	if type(componentId) ~= "string" or componentId == "" then return false end
	if self.Selected[componentId] then
		self.Selected[componentId] = nil
		self:_destroyHighlight(componentId)
		return false
	end
	self.Selected[componentId] = true
	self:_show(componentId)
	return true
end

function BuildSelection:Set(componentIds)
	self:Clear()
	for _, componentId in ipairs(componentIds or {}) do
		if type(componentId) == "string" and componentId ~= "" then
			self.Selected[componentId] = true
		end
	end
	for componentId in pairs(self.Selected) do self:_show(componentId) end
end

function BuildSelection:SelectAll()
	if not self.MechId then return 0 end
	local assemblies = workspace:FindFirstChild("MechAssemblies")
	local mech = assemblies and assemblies:FindFirstChild(self.MechId)
	if not mech or not mech:IsA("Model") then return 0 end
	local ids = {}
	for _, child in ipairs(mech:GetChildren()) do
		if child:IsA("Model") then
			local componentId = child:GetAttribute("ComponentId")
			if type(componentId) == "string" then table.insert(ids, componentId) end
		end
	end
	table.sort(ids)
	self:Set(ids)
	return #ids
end

function BuildSelection:GetIds()
	local ids = {}
	for componentId in pairs(self.Selected) do table.insert(ids, componentId) end
	table.sort(ids)
	return ids
end

function BuildSelection:Count()
	local count = 0
	for _ in pairs(self.Selected) do count += 1 end
	return count
end

function BuildSelection:Clear()
	for componentId in pairs(self.Highlights) do self:_destroyHighlight(componentId) end
	table.clear(self.Selected)
end

function BuildSelection:Refresh()
	for componentId in pairs(self.Selected) do
		local current = self.Highlights[componentId]
		if not current or not current.Parent then
			self.Highlights[componentId] = nil
			self:_show(componentId)
		end
	end
end

function BuildSelection:Destroy()
	self:Clear()
	self.MechId = nil
end

return BuildSelection
