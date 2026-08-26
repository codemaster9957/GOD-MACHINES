--!strict
-- Editable factory blueprints assembled exclusively from the canonical 100-piece catalog.

local PresetBlueprints = {}
local definitions: {[string]: any} = {}
local ordered: {any} = {}

local PALETTES = {
	Scout = {Primary=Color3.fromRGB(224,232,236),Secondary=Color3.fromRGB(40,49,58),Accent=Color3.fromRGB(74,235,196),Mechanical=Color3.fromRGB(92,103,112)},
	Siege = {Primary=Color3.fromRGB(91,102,77),Secondary=Color3.fromRGB(35,39,32),Accent=Color3.fromRGB(255,177,58),Mechanical=Color3.fromRGB(70,72,68)},
	Vanguard = {Primary=Color3.fromRGB(52,75,112),Secondary=Color3.fromRGB(225,229,235),Accent=Color3.fromRGB(255,186,48),Mechanical=Color3.fromRGB(62,69,80)},
	Light = {Primary=Color3.fromRGB(238,241,246),Secondary=Color3.fromRGB(40,50,68),Accent=Color3.fromRGB(70,218,255),Mechanical=Color3.fromRGB(88,96,110)},
	Medium = {Primary=Color3.fromRGB(197,54,61),Secondary=Color3.fromRGB(232,234,226),Accent=Color3.fromRGB(255,204,54),Mechanical=Color3.fromRGB(64,66,73)},
	Heavy = {Primary=Color3.fromRGB(47,51,63),Secondary=Color3.fromRGB(126,37,50),Accent=Color3.fromRGB(255,91,65),Mechanical=Color3.fromRGB(75,78,88)},
	Buggy = {Primary=Color3.fromRGB(229,139,35),Secondary=Color3.fromRGB(38,41,45),Accent=Color3.fromRGB(87,220,255),Mechanical=Color3.fromRGB(91,87,78)},
	Battle = {Primary=Color3.fromRGB(68,79,84),Secondary=Color3.fromRGB(28,33,37),Accent=Color3.fromRGB(231,73,49),Mechanical=Color3.fromRGB(74,79,80)},
	Hover = {Primary=Color3.fromRGB(224,231,239),Secondary=Color3.fromRGB(43,55,78),Accent=Color3.fromRGB(167,100,255),Mechanical=Color3.fromRGB(84,94,112)},
}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}; for key,item in pairs(value) do out[key]=clone(item) end; return out
end

local function piece(id: string, partType: string, x: number, y: number, z: number, palette: any, rx: number?, ry: number?, rz: number?): any
	return {
		Id=id, PartType=partType,
		LocalTransform=CFrame.new(x,y,z)*CFrame.Angles(math.rad(rx or 0),math.rad(ry or 0),math.rad(rz or 0)),
		Metadata={Paint=clone(palette)},
	}
end

local function factory(id: string, displayName: string, className: string, description: string, difficulty: string, components: {any}): any
	local map = {}; local connections = {}; local rootId = components[1].Id
	for _,component in ipairs(components) do
		map[component.Id]=component
		if component.Id ~= rootId then
			local edgeId="factory_"..rootId.."_"..component.Id
			connections[edgeId]={Id=edgeId,A=rootId,B=component.Id,StructuralStrength=900}
		end
	end
	local blueprint={
		Id=id, Name=id, DisplayName=displayName, Class=className, Description=description,
		Difficulty=difficulty, FactoryPreset=true, Components=map, Connections=connections,
		PrimaryComponentId=rootId,
	}
	definitions[id]=blueprint; table.insert(ordered,blueprint); return blueprint
end

factory("ScoutStrider", "SK-7 Scout Strider", "RECON WALKER", "Fast two-legged reconnaissance machine with omni-foot drive and a light autocannon.", "EASY", {
	piece("root","SpineBeam",0,7,0,PALETTES.Scout), piece("chest","CompactFrame",0,9,0,PALETTES.Scout),
	piece("pod","RemoteCore",0,10.8,-.2,PALETTES.Scout), piece("sensor","SensorMast",0,13,0,PALETTES.Scout),
	piece("hip","CrossJunction",0,5,0,PALETTES.Scout), piece("legL","LatticeBeam",-2.2,2.7,0,PALETTES.Scout,0,0,8),
	piece("legR","LatticeBeam",2.2,2.7,0,PALETTES.Scout,0,0,-8), piece("footL","OmniWheel",-2.4,.6,0,PALETTES.Scout),
	piece("footR","OmniWheel",2.4,.6,0,PALETTES.Scout), piece("motor","ElectricMotor",0,7,2.7,PALETTES.Scout),
	piece("battery","BatteryPack",0,8.7,2.8,PALETTES.Scout), piece("generator","MicroGenerator",0,6.5,3,PALETTES.Scout), piece("gun","Autocannon",2.8,9,-1.8,PALETTES.Scout,0,-8,0),
	piece("shield","LightArmourPlate",-2.8,9,-.4,PALETTES.Scout,0,0,90),
})

factory("SiegeTank", "Bastion Siege Tank", "HEAVY SIEGE", "A fortress on tracks carrying a heavy cannon, missile rack and layered composite armour.", "MEDIUM", {
	piece("root","HeavyFrame",0,4,0,PALETTES.Siege), piece("hullFront","HeavyFrame",0,4,-5,PALETTES.Siege),
	piece("hullRear","HeavyFrame",0,4,5,PALETTES.Siege), piece("engine","HeavyDieselEngine",0,5.2,5,PALETTES.Siege),
	piece("fuel","FuelTank",0,7,6,PALETTES.Siege), piece("generator","MicroGenerator",0,6.5,3.5,PALETTES.Siege), piece("remote","RemoteCore",0,5.8,1,PALETTES.Siege),
	piece("trackFL","TrackSprocket",-4,2,-5.5,PALETTES.Siege,0,0,90), piece("trackFR","TrackSprocket",4,2,-5.5,PALETTES.Siege,0,0,90),
	piece("trackBL","TrackSprocket",-4,2,5.5,PALETTES.Siege,0,0,90), piece("trackBR","TrackSprocket",4,2,5.5,PALETTES.Siege,0,0,90),
	piece("bogieL","TrackBogie",-4,2,0,PALETTES.Siege,0,0,90), piece("bogieR","TrackBogie",4,2,0,PALETTES.Siege,0,0,90),
	piece("turret","RingFrame",0,7,-1,PALETTES.Siege), piece("cannon","HeavyCannon",0,8,-7,PALETTES.Siege),
	piece("missiles","MissileRack",3.2,8,-1,PALETTES.Siege), piece("armourL","CompositeShell",-3.5,5,0,PALETTES.Siege),
	piece("armourR","CompositeShell",3.5,5,0,PALETTES.Siege), piece("ram","RamPlate",0,4,-8,PALETTES.Siege),
})

factory("VanguardWalker", "Vanguard VX Walker", "ASSAULT WALKER", "Balanced battlefield walker with twin powered feet, cannon and missile support.", "MEDIUM", {
	piece("root","HeavyFrame",0,9,0,PALETTES.Vanguard), piece("torso","CompositeShell",0,10,0,PALETTES.Vanguard),
	piece("core","FusionReactor",0,9,3,PALETTES.Vanguard), piece("remote","CommandPod",0,12,-.5,PALETTES.Vanguard),
	piece("hip","CrossJunction",0,6,0,PALETTES.Vanguard), piece("thighL","SpineBeam",-2.7,3.7,0,PALETTES.Vanguard,0,0,7),
	piece("thighR","SpineBeam",2.7,3.7,0,PALETTES.Vanguard,0,0,-7), piece("footL","SteeringWheelModule",-3,.8,0,PALETTES.Vanguard),
	piece("footR","SteeringWheelModule",3,.8,0,PALETTES.Vanguard), piece("motorL","HighTorqueMotor",-2.6,6,2.5,PALETTES.Vanguard),
	piece("motorR","HighTorqueMotor",2.6,6,2.5,PALETTES.Vanguard), piece("gun","RotaryCannon",3.7,10,-2,PALETTES.Vanguard),
	piece("missiles","RocketPod",-3.7,10,-1,PALETTES.Vanguard), piece("shoulderL","CurvedShield",-3.8,11,0,PALETTES.Vanguard,0,0,90),
	piece("shoulderR","CurvedShield",3.8,11,0,PALETTES.Vanguard,0,0,-90), piece("cooler","Radiator",0,10,4,PALETTES.Vanguard),
})

factory("LightHumanoid", "Aerial Lancer L1", "LIGHT HUMANOID", "Agile Gundam-inspired light suit with beam weapon, shield and vector backpack.", "EASY", {
	piece("root","CompactFrame",0,8,0,PALETTES.Light), piece("chest","WedgeNose",0,9,-1,PALETTES.Light,90,0,0),
	piece("head","RemoteCore",0,12,0,PALETTES.Light), piece("sensor","SensorMast",0,14,0,PALETTES.Light),
	piece("waist","RingFrame",0,6,0,PALETTES.Light), piece("legL","LatticeBeam",-2,3.4,0,PALETTES.Light),
	piece("legR","LatticeBeam",2,3.4,0,PALETTES.Light), piece("footL","OmniWheel",-2,.7,-.4,PALETTES.Light),
	piece("footR","OmniWheel",2,.7,-.4,PALETTES.Light), piece("armL","TriTruss",-3.6,8,0,PALETTES.Light,0,0,90),
	piece("armR","TriTruss",3.6,8,0,PALETTES.Light,0,0,90), piece("beam","BeamEmitter",3.7,7,-3,PALETTES.Light),
	piece("shield","CurvedShield",-4,8,-1,PALETTES.Light,0,0,90), piece("reactor","SmallReactor",0,8,3,PALETTES.Light),
	piece("thrusterL","VectorThruster",-2,9,4,PALETTES.Light), piece("thrusterR","VectorThruster",2,9,4,PALETTES.Light),
})

factory("MediumHumanoid", "Crimson Paladin M4", "MEDIUM HUMANOID", "Classic all-round combat suit with rifle, rockets and reinforced shoulder armour.", "MEDIUM", {
	piece("root","HeavyFrame",0,9,0,PALETTES.Medium), piece("chest","CompositeShell",0,10,-.5,PALETTES.Medium),
	piece("head","CommandPod",0,13,0,PALETTES.Medium), piece("waist","RingFrame",0,6.5,0,PALETTES.Medium),
	piece("legL","SpineBeam",-2.4,3.5,0,PALETTES.Medium), piece("legR","SpineBeam",2.4,3.5,0,PALETTES.Medium),
	piece("footL","SteeringWheelModule",-2.5,.7,-.5,PALETTES.Medium), piece("footR","SteeringWheelModule",2.5,.7,-.5,PALETTES.Medium),
	piece("armL","LatticeBeam",-4,9,0,PALETTES.Medium,0,0,90), piece("armR","LatticeBeam",4,9,0,PALETTES.Medium,0,0,90),
	piece("rifle","Railgun",4.3,8,-4,PALETTES.Medium), piece("rockets","RocketPod",-4.2,10,-1,PALETTES.Medium),
	piece("reactor","FusionReactor",0,9,3.5,PALETTES.Medium), piece("battery","CapacitorBank",0,6.5,3,PALETTES.Medium),
	piece("shoulderL","SlopedArmour",-4,11,0,PALETTES.Medium,0,0,90), piece("shoulderR","SlopedArmour",4,11,0,PALETTES.Medium,0,0,-90),
})

factory("HeavyHumanoid", "Dreadnought H9", "HEAVY HUMANOID", "Towering assault suit with extreme armour, rotary cannon and shoulder missiles.", "ADVANCED", {
	piece("root","HeavyFrame",0,11,0,PALETTES.Heavy), piece("chestA","CompositeShell",0,12,-1,PALETTES.Heavy),
	piece("chestB","BlastPlate",0,12,-3,PALETTES.Heavy), piece("head","ArmouredCockpit",0,15,0,PALETTES.Heavy),
	piece("waist","HexHub",0,8,0,PALETTES.Heavy), piece("legL","HeavyFrame",-3.2,4.5,0,PALETTES.Heavy),
	piece("legR","HeavyFrame",3.2,4.5,0,PALETTES.Heavy), piece("footL","TrackSprocket",-3.2,.9,0,PALETTES.Heavy,0,0,90),
	piece("footR","TrackSprocket",3.2,.9,0,PALETTES.Heavy,0,0,90), piece("armL","SpineBeam",-5.5,10,0,PALETTES.Heavy,0,0,90),
	piece("armR","SpineBeam",5.5,10,0,PALETTES.Heavy,0,0,90), piece("rotary","RotaryCannon",5.8,9,-4,PALETTES.Heavy),
	piece("missilesL","MissileRack",-5,12,-1,PALETTES.Heavy), piece("missilesR","MissileRack",5,12,-1,PALETTES.Heavy),
	piece("engine","HeavyDieselEngine",0,10,4,PALETTES.Heavy), piece("fuel","FuelTank",0,7,4,PALETTES.Heavy), piece("generator","MicroGenerator",0,8.5,4,PALETTES.Heavy),
	piece("armourL","CompositeShell",-5,11,0,PALETTES.Heavy), piece("armourR","CompositeShell",5,11,0,PALETTES.Heavy),
})

factory("CombatBuggy", "Jackal Combat Buggy", "FAST ATTACK", "Light four-wheel raider with responsive steering, machine gun and rocket pod.", "EASY", {
	piece("root","CompactFrame",0,3,0,PALETTES.Buggy), piece("rear","SkidFrame",0,3,4,PALETTES.Buggy),
	piece("nose","WedgeNose",0,3,-4,PALETTES.Buggy), piece("seat","PilotSeat",0,4,1,PALETTES.Buggy),
	piece("remote","RemoteCore",0,3,3,PALETTES.Buggy), piece("engine","SmallCombustionEngine",0,3.5,4,PALETTES.Buggy),
	piece("fuel","FuelTank",0,5,4,PALETTES.Buggy), piece("generator","MicroGenerator",0,2.5,2,PALETTES.Buggy), piece("frontL","SteeringWheelModule",-3,1,-3.2,PALETTES.Buggy,0,0,90),
	piece("frontR","SteeringWheelModule",3,1,-3.2,PALETTES.Buggy,0,0,90), piece("rearL","SuspensionWheel",-3,1,3.5,PALETTES.Buggy,0,0,90),
	piece("rearR","SuspensionWheel",3,1,3.5,PALETTES.Buggy,0,0,90), piece("gun","MachineGun",0,6,-1,PALETTES.Buggy),
	piece("rockets","RocketPod",2,4,1,PALETTES.Buggy), piece("ram","RamPlate",0,2.5,-6,PALETTES.Buggy),
})

factory("TrackedBattleTank", "Ravager Battle Tank", "MAIN BATTLE TANK", "Mobile battle tank balancing armour, speed, railgun range and secondary fire.", "MEDIUM", {
	piece("root","HeavyFrame",0,4,0,PALETTES.Battle), piece("front","HeavyFrame",0,4,-4.5,PALETTES.Battle),
	piece("rear","HeavyFrame",0,4,4.5,PALETTES.Battle), piece("engine","HeavyDieselEngine",0,5,5,PALETTES.Battle),
	piece("fuel","FuelTank",0,7,5,PALETTES.Battle), piece("generator","MicroGenerator",0,6,3,PALETTES.Battle), piece("remote","RemoteCore",0,6,1,PALETTES.Battle),
	piece("driveL","TrackSprocket",-4,2,-4.8,PALETTES.Battle,0,0,90), piece("driveR","TrackSprocket",4,2,-4.8,PALETTES.Battle,0,0,90),
	piece("bogieL","TrackBogie",-4,2,1,PALETTES.Battle,0,0,90), piece("bogieR","TrackBogie",4,2,1,PALETTES.Battle,0,0,90),
	piece("turret","RingFrame",0,7,-1,PALETTES.Battle), piece("railgun","Railgun",0,8,-7,PALETTES.Battle),
	piece("secondary","MachineGun",2,9,-2,PALETTES.Battle), piece("skirtL","SideSkirt",-4.2,3,0,PALETTES.Battle),
	piece("skirtR","SideSkirt",4.2,3,0,PALETTES.Battle), piece("frontArmour","SlopedArmour",0,5,-7,PALETTES.Battle),
})

factory("Hovercraft", "Spectre Hovercraft", "HOVER ASSAULT", "Low-profile hover machine with four lift fans, vector thrust and a beam emitter.", "ADVANCED", {
	piece("root","KeelFrame",0,4,0,PALETTES.Hover), piece("body","RingFrame",0,5,0,PALETTES.Hover),
	piece("nose","WedgeNose",0,4,-5,PALETTES.Hover), piece("pod","CommandPod",0,7,-1,PALETTES.Hover),
	piece("reactor","FusionReactor",0,5,3,PALETTES.Hover), piece("fanFL","LiftFan",-4,2,-3,PALETTES.Hover),
	piece("fanFR","LiftFan",4,2,-3,PALETTES.Hover), piece("fanBL","LiftFan",-4,2,3,PALETTES.Hover),
	piece("fanBR","LiftFan",4,2,3,PALETTES.Hover), piece("thrustL","VectorThruster",-3,4,6,PALETTES.Hover),
	piece("thrustR","VectorThruster",3,4,6,PALETTES.Hover), piece("weapon","BeamEmitter",0,7,-5,PALETTES.Hover),
	piece("wingL","StubWing",-5,4,0,PALETTES.Hover), piece("wingR","StubWing",5,4,0,PALETTES.Hover,0,0,180),
	piece("battery","HeavyBattery",0,4,4,PALETTES.Hover), piece("cooler","HeatSink",0,6,4,PALETTES.Hover),
})

function PresetBlueprints.Get(id: string): any?
	local value=definitions[id]; return value and clone(value) or nil
end

function PresetBlueprints.List(): {any}
	local result={}
	for _,blueprint in ipairs(ordered) do
		table.insert(result,{Name=blueprint.Id,DisplayName=blueprint.DisplayName,PartCount=(function() local n=0; for _ in pairs(blueprint.Components) do n+=1 end; return n end)(),Class=blueprint.Class,Description=blueprint.Description,Difficulty=blueprint.Difficulty,FactoryPreset=true,SavedAt=0})
	end
	return result
end

return table.freeze(PresetBlueprints)
