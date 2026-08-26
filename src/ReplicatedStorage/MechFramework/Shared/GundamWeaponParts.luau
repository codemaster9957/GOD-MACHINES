--!strict
-- Adapts the original humanoid-mech weapon catalogue into the current declarative part library.
-- Autocannon already exists in the legacy 100-part set; the remaining records are additive.

local H = require(script.Parent:WaitForChild("PartDefinitionHelpers"))
local WeaponCatalog = require(script.Parent:WaitForChild("WeaponCatalog"))

local parts = {}

local function scaled(value: number, minimum: number): number
	return math.max(minimum, value)
end

local function geometry(record: any): {any}
	local size: Vector3 = record.Size
	local visual = record.Visual or {}
	local material = if visual.Material == "Neon" then Enum.Material.Neon elseif visual.Material == "DiamondPlate" then Enum.Material.DiamondPlate else Enum.Material.Metal
	local body = Vector3.new(scaled(size.X * 0.78, 0.35), scaled(size.Y * 0.72, 0.35), scaled(size.Z * 0.48, 0.5))
	local nose = Vector3.new(scaled(size.X * 0.5, 0.3), scaled(size.Y * 0.5, 0.3), scaled(size.Z * 0.42, 0.45))
	local emitterLength = scaled(size.Z * 0.38, 0.45)
	local emitterWidth = scaled(math.min(size.X, size.Y) * 0.2, 0.18)
	local mount = Vector3.new(scaled(size.X * 0.55, 0.3), scaled(size.Y * 0.22, 0.2), scaled(size.Z * 0.22, 0.3))

	local out = {
		H.block("Housing", body, CFrame.new(0, 0, size.Z * 0.16), "Primary", material),
		H.block("ForwardAssembly", nose, CFrame.new(0, 0, -size.Z * 0.24), "Secondary", Enum.Material.Metal),
		H.cylinder("Emitter", Vector3.new(emitterLength, emitterWidth, emitterWidth), CFrame.new(0, 0, -size.Z * 0.39) * CFrame.Angles(0, math.rad(90), 0), "Accent", if visual.Material == "Neon" then Enum.Material.Neon else Enum.Material.Metal),
		H.block("Mount", mount, CFrame.new(0, -size.Y * 0.38, size.Z * 0.15), "Mechanical", Enum.Material.DiamondPlate),
	}

	if record.MountRole == "Shoulder" or record.MountRole == "Chest" then
		table.insert(out, H.block("ArmourShroud", Vector3.new(scaled(size.X * 0.9, 0.4), scaled(size.Y * 0.18, 0.18), scaled(size.Z * 0.55, 0.5)), CFrame.new(0, size.Y * 0.38, 0), "Secondary", Enum.Material.Metal))
	elseif record.MountRole == "Hand" then
		table.insert(out, H.block("Grip", Vector3.new(scaled(size.X * 0.28, 0.2), scaled(size.Y * 0.45, 0.3), scaled(size.Z * 0.2, 0.25)), CFrame.new(0, -size.Y * 0.28, size.Z * 0.28), "Mechanical", Enum.Material.Metal))
	elseif record.MountRole == "Head" then
		table.insert(out, H.ball("Sensor", Vector3.new(scaled(size.X * 0.28, 0.2), scaled(size.Y * 0.28, 0.2), scaled(size.Z * 0.18, 0.18)), CFrame.new(0, size.Y * 0.2, -size.Z * 0.28), "Accent", Enum.Material.Neon))
	end
	return out
end

for _, record in ipairs(WeaponCatalog.Ordered) do
	if record.Id == "Autocannon" then
		continue
	end
	local visual = record.Visual or {}
	local collection = record.Collection or {}
	local defaults = {
		Primary = visual.BaseColor or H.DefaultPaint.Primary,
		Secondary = H.DefaultPaint.Secondary,
		Accent = visual.AccentColor or H.DefaultPaint.Accent,
		Glass = H.DefaultPaint.Glass,
		Mechanical = H.DefaultPaint.Mechanical,
	}
	local description = record.DisplayName .. " modular humanoid-mech weapon configured for " .. string.lower(record.MountRole) .. " mounting and server-authoritative combat."
	table.insert(parts, H.part(
		record.Id,
		record.DisplayName,
		record.ShortName,
		description,
		record.Size,
		record.Mass,
		record.MaxHealth,
		geometry(record),
		{
			Category = "Weapons",
			Rarity = collection.Rarity or "Uncommon",
			Stackable = false,
			AttachmentNodes = H.boxNodes(record.Size, "Weapon", {"Structural", "Weapon"}),
			PaintDefaults = defaults,
			Power = record.Power,
			Heat = record.Heat,
			Combat = record.Combat,
			Controls = {record.DefaultAction},
			MountRole = record.MountRole,
			MaxDurability = collection.MaxDurability or record.MaxHealth,
		}
	))
end

return parts
