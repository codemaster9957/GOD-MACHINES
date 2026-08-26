--!strict
-- Optional server-side readiness/preferences for the additive 100-point polish pack.
-- This service never owns authoritative gameplay state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local framework = ReplicatedStorage:WaitForChild("MechFramework")
local Catalog = require(framework:WaitForChild("Shared"):WaitForChild("PolishCatalog"))

local Polish: any = {}

local function validateCatalog(): number
	assert(Catalog.MasterEnabled == true or Catalog.MasterEnabled == false, "PolishCatalog.MasterEnabled must be boolean")
	assert(type(Catalog.Version) == "string" and #Catalog.Version > 0, "PolishCatalog.Version must be non-empty")
	assert(type(Catalog.Items) == "table", "PolishCatalog.Items must be a table")
	assert(#Catalog.Items == 100, "PolishCatalog must contain exactly 100 items")

	local seen: {[string]: boolean} = {}
	local enabledCount = 0
	for index, item in ipairs(Catalog.Items) do
		assert(type(item) == "table", string.format("Polish item %d must be a table", index))
		assert(type(item.Id) == "string" and item.Id:match("^[A-Z]%d%d$") ~= nil, "Invalid polish item id")
		assert(type(item.Group) == "string" and #item.Group > 0, "Polish item group is required")
		assert(type(item.Name) == "string" and #item.Name > 0, "Polish item name is required")
		assert(type(item.Description) == "string" and #item.Description > 0, "Polish item description is required")
		assert(type(item.Scope) == "string" and #item.Scope > 0, "Polish item scope is required")
		assert(type(item.Enabled) == "boolean", "Polish item enabled flag must be boolean")
		assert(not seen[item.Id], "Duplicate polish item id " .. item.Id)
		seen[item.Id] = true
		if item.Enabled then
			enabledCount += 1
		end
	end

	return enabledCount
end

local function setDefaultAttribute(player: Player, name: string, value: any)
	if player:GetAttribute(name) == nil then
		player:SetAttribute(name, value)
	end
end

local function seedPlayer(player: Player)
	setDefaultAttribute(player, "PolishEnabled", Catalog.MasterEnabled)
	setDefaultAttribute(player, "PolishReducedMotion", Catalog.Defaults.ReducedMotion)
	setDefaultAttribute(player, "PolishCameraMotion", Catalog.Defaults.CameraMotion)
	setDefaultAttribute(player, "PolishScreenFlash", Catalog.Defaults.ScreenFlash)
	setDefaultAttribute(player, "PolishVignette", Catalog.Defaults.Vignette)
	setDefaultAttribute(player, "PolishHighContrast", false)
	setDefaultAttribute(player, "PolishCrosshairScale", Catalog.Defaults.CrosshairScale)
	setDefaultAttribute(player, "PolishTextScale", Catalog.Defaults.TextScale)
	setDefaultAttribute(player, "PolishSessionStartedAt", workspace:GetServerTimeNow())
end

function Polish:Init(_container: any)
	framework:SetAttribute("PolishPackReady", false)
	local enabledCount = validateCatalog()
	framework:SetAttribute("PolishPackVersion", Catalog.Version)
	framework:SetAttribute("PolishEnabledCount", enabledCount)
end

function Polish:Start()
	for _, player in ipairs(Players:GetPlayers()) do
		seedPlayer(player)
	end
	Players.PlayerAdded:Connect(seedPlayer)
	framework:SetAttribute("PolishPackReady", Catalog.MasterEnabled)
	print(string.format("[MechFramework] PolishService ready (%d/%d improvements enabled)", framework:GetAttribute("PolishEnabledCount") or 0, #Catalog.Items))
end

return Polish
