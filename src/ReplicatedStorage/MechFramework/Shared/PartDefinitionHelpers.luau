--!strict
-- Shared constructors used by the declarative GOD MACHINES part library.

local H = {}

H.DefaultPaint = table.freeze({
	Primary = Color3.fromRGB(92, 98, 104),
	Secondary = Color3.fromRGB(44, 48, 53),
	Accent = Color3.fromRGB(255, 174, 52),
	Glass = Color3.fromRGB(74, 170, 205),
	Mechanical = Color3.fromRGB(32, 35, 39),
})

local ALL_TYPES = { "Structural", "Utility", "Weapon", "Mobility", "Aero", "Control" }

local function copyArray(values: {string}?): {string}
	local out = {}
	for _, value in ipairs(values or ALL_TYPES) do
		table.insert(out, value)
	end
	return out
end

function H.node(name: string, nodeType: string, transform: CFrame, accepts: {string}?): any
	local compatible = copyArray(accepts)
	return {
		Name = name,
		Type = nodeType,
		Transform = transform,
		Accepts = compatible,
		CompatibleWith = copyArray(compatible),
	}
end

function H.boxNodes(size: Vector3, nodeType: string?, accepts: {string}?): {any}
	local kind = nodeType or "Structural"
	return {
		H.node("Top", kind, CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0), accepts),
		H.node("Bottom", kind, CFrame.new(0, -size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0), accepts),
		H.node("Left", kind, CFrame.new(-size.X / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), accepts),
		H.node("Right", kind, CFrame.new(size.X / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), accepts),
		H.node("Front", kind, CFrame.new(0, 0, -size.Z / 2), accepts),
		H.node("Back", kind, CFrame.new(0, 0, size.Z / 2) * CFrame.Angles(0, math.pi, 0), accepts),
	}
end

local function primitive(kind: string, name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return {
		Kind = kind,
		Name = name,
		Size = size,
		CFrame = transform or CFrame.identity,
		Region = region or "Primary",
		Material = material or Enum.Material.Metal,
		Role = role,
	}
end

function H.block(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return primitive("Block", name, size, transform, region, material, role)
end

function H.wedge(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("Wedge", name, size, transform, region, material, nil)
end

function H.cornerWedge(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("CornerWedge", name, size, transform, region, material, nil)
end

function H.cylinder(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?, role: string?): any
	return primitive("Cylinder", name, size, transform, region, material, role)
end

function H.ball(name: string, size: Vector3, transform: CFrame?, region: string?, material: Enum.Material?): any
	return primitive("Ball", name, size, transform, region, material, nil)
end

function H.seat(name: string, size: Vector3, transform: CFrame?, region: string?, vehicle: boolean?): any
	return primitive(if vehicle then "VehicleSeat" else "Seat", name, size, transform, region, Enum.Material.Metal, "PilotSeat")
end

function H.glass(name: string, size: Vector3, transform: CFrame?, region: string?): any
	local out = primitive("Block", name, size, transform, region or "Glass", Enum.Material.Glass, nil)
	out.Transparency = 0.28
	return out
end

function H.radialBlades(prefix: string, count: number, radius: number, length: number, width: number, depth: number, center: CFrame?, region: string?): {any}
	local out = {}
	local base = center or CFrame.identity
	for index = 1, count do
		local angle = ((index - 1) / count) * math.pi * 2
		local transform = base * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius, 0)
		table.insert(out, H.wedge(prefix .. tostring(index), Vector3.new(depth, length, width), transform, region or "Accent", Enum.Material.Metal))
	end
	return out
end

function H.append(target: {any}, values: {any})
	for _, value in ipairs(values) do
		table.insert(target, value)
	end
end

function H.part(id: string, displayName: string, shortName: string, category: string, description: string, size: Vector3, mass: number, health: number, geometry: {any}, extra: any?): any
	local definition: any = {
		Id = id,
		DisplayName = displayName,
		ShortName = shortName,
		Category = category,
		Description = description,
		Size = size,
		Mass = mass,
		MaxHealth = health,
		Rarity = "Common",
		Stackable = true,
		PaintDefaults = H.DefaultPaint,
		PaintRegions = { "Primary", "Secondary", "Accent", "Glass", "Mechanical" },
		AttachmentNodes = H.boxNodes(size, "Structural"),
		PhysicalProperties = {
			Density = 1,
			StructuralStrength = health * 1.45,
		},
		Geometry = geometry,
	}
	for key, value in pairs(extra or {}) do
		definition[key] = value
	end
	return definition
end

return H
