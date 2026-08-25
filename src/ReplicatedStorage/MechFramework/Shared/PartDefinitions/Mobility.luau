--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(def) table.insert(parts, def) end
local ACCEPT = {"Structural","Mobility"}
local function nodes(size) return H.boxNodes(size, "Mobility", ACCEPT) end

add(H.part("SmallWheel", "Small Wheel", "SMALL WHEEL", "Compact rubber wheel for light scouts, carts and stabilisers.", Vector3.new(2.2,2.2,1.4), 14, 150, {
	H.cylinder("Tyre", Vector3.new(1.1,2.1,2.1), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Hub", Vector3.new(1.25,.9,.9), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"),
	H.cylinder("Axle", Vector3.new(1.4,.35,.35), CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="Mobility", AttachmentNodes=nodes(Vector3.new(2.2,2.2,1.4)), Mobility={Kind="Wheel",Radius=1.05,Drive=false,Steer=false,Grip=1.0,RollingResistance=.05}}))

add(H.part("StandardWheel", "Standard Wheel", "WHEEL", "General-purpose powered-ready wheel with six-spoke industrial hub.", Vector3.new(3.2,3.2,1.8), 24, 220, {
	H.cylinder("Tyre", Vector3.new(1.35,3.05,3.05), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(1.45,2.05,2.05), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"),
	H.cylinder("Hub", Vector3.new(1.6,.75,.75), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"), H.block("Fork", Vector3.new(.45,2.4,.55), CFrame.new(.65,0,0), "Mechanical"),
}, {Category="Mobility", AttachmentNodes=nodes(Vector3.new(3.2,3.2,1.8)), Mobility={Kind="Wheel",Radius=1.52,Drive=true,Steer=false,Grip=1.15,DriveTorque=900,RollingResistance=.045}, Power={Generation=0,Demand=0}}))

add(H.part("HeavyWheel", "Heavy Wheel", "HEAVY WHEEL", "Thick reinforced wheel with a deep steel rim for armoured vehicles.", Vector3.new(4,4,2.4), 48, 360, {
	H.cylinder("Tyre", Vector3.new(1.75,3.9,3.9), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("OuterRim", Vector3.new(1.85,3,3), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"),
	H.cylinder("InnerHub", Vector3.new(2.05,1.25,1.25), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"), H.block("Arm", Vector3.new(.55,3.2,.7), CFrame.new(.9,0,0), "Mechanical"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(4,4,2.4)), Mobility={Kind="Wheel",Radius=1.95,Drive=true,Steer=false,Grip=1.3,DriveTorque=1800,RollingResistance=.055}}))

add(H.part("MonsterWheel", "Monster Wheel", "MONSTER", "Huge high-clearance wheel for absurd machines that refuse to care about terrain.", Vector3.new(6,6,3), 95, 520, {
	H.cylinder("Tyre", Vector3.new(2.2,5.9,5.9), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(2.35,3.8,3.8), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("Hub", Vector3.new(2.55,1.5,1.5), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"),
	H.block("HubGuard", Vector3.new(.55,2.5,2.5), CFrame.new(1.15,0,0), "Primary"),
}, {Category="Mobility", Rarity="Rare", Stackable=false, AttachmentNodes=nodes(Vector3.new(6,6,3)), Mobility={Kind="Wheel",Radius=2.95,Drive=true,Steer=false,Grip=1.45,DriveTorque=3600,RollingResistance=.065}}))

add(H.part("OffroadWheel", "Off-Road Wheel", "OFFROAD", "Knobbly expedition wheel with protective hub cap and high terrain grip.", Vector3.new(4.5,4.5,2.3), 42, 330, {
	H.cylinder("Tyre", Vector3.new(1.7,4.35,4.35), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(1.85,2.7,2.7), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("HubCap", Vector3.new(2.05,1.25,1.25), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.DiamondPlate, "WheelSpinner"),
	H.block("MudGuard", Vector3.new(.35,1.1,4.2), CFrame.new(.95,1.35,0), "Primary"),
}, {Category="Mobility", AttachmentNodes=nodes(Vector3.new(4.5,4.5,2.3)), Mobility={Kind="Wheel",Radius=2.18,Drive=true,Steer=false,Grip=1.65,DriveTorque=1700,RollingResistance=.075}}))

add(H.part("ArmouredWheel", "Armoured Wheel", "ARM WHEEL", "Protected wheel with an external armour disc shielding the hub and axle.", Vector3.new(4.2,4.2,2.8), 61, 470, {
	H.cylinder("Tyre", Vector3.new(1.65,4,4), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(1.85,2.8,2.8), CFrame.Angles(0,0,math.rad(90)), "Mechanical", Enum.Material.Metal, "WheelSpinner"), H.cylinder("ArmourDisc", Vector3.new(.45,3.35,3.35), CFrame.new(-1.05,0,0)*CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.DiamondPlate, "WheelSpinner"),
	H.cylinder("Boss", Vector3.new(.55,.9,.9), CFrame.new(-1.28,0,0)*CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(4.2,4.2,2.8)), Mobility={Kind="Wheel",Radius=2,Drive=true,Steer=false,Grip=1.25,DriveTorque=2000,RollingResistance=.08}}))

add(H.part("SteeringWheelModule", "Steering Wheel Module", "STEER WHEEL", "Complete steerable corner module with knuckle, fork and wheel.", Vector3.new(4,4,3.4), 49, 350, {
	H.cylinder("Tyre", Vector3.new(1.45,3.6,3.6), CFrame.new(-.45,-.35,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(1.55,2.4,2.4), CFrame.new(-.45,-.35,0)*CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"),
	H.block("SteerPost", Vector3.new(.65,2.6,.65), CFrame.new(1.05,.55,0), "Mechanical", Enum.Material.Metal, "SteeringVisual"), H.block("Fork", Vector3.new(1.5,.55,.7), CFrame.new(.35,-.8,0), "Accent", Enum.Material.Metal, "SteeringVisual"), H.cylinder("TopBearing", Vector3.new(.5,1.1,1.1), CFrame.new(1.05,1.55,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(4,4,3.4)), Mobility={Kind="Wheel",Radius=1.8,Drive=true,Steer=true,Grip=1.25,DriveTorque=1500,SteerAngle=34,RollingResistance=.055}, Controls={"Throttle","Steer"}}))

add(H.part("PoweredWheelModule", "Powered Wheel Module", "POWER WHEEL", "Integrated electric hub motor and wheel for compact drivetrains.", Vector3.new(3.6,3.6,2.8), 43, 310, {
	H.cylinder("Tyre", Vector3.new(1.4,3.45,3.45), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("MotorShell", Vector3.new(1.75,2.55,2.55), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("RotorCap", Vector3.new(1.95,1.1,1.1), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Neon, "WheelSpinner"), H.block("CableBox", Vector3.new(.55,.9,1), CFrame.new(1.15,.8,0), "Mechanical"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(3.6,3.6,2.8)), Mobility={Kind="Wheel",Radius=1.72,Drive=true,Steer=false,Grip=1.2,DriveTorque=1350,RollingResistance=.05}, Power={Generation=0,Demand=18,Priority=35}, Heat={Generation=5,Capacity=75}, Controls={"Throttle"}}))

add(H.part("OmniWheel", "Omni Wheel", "OMNI", "Low-friction lateral wheel assembly for strange holonomic machines.", Vector3.new(3.8,3.8,2.7), 38, 270, {
	H.cylinder("Core", Vector3.new(1.1,2.6,2.6), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("RollerA", Vector3.new(.65,.8,.8), CFrame.new(0,1.35,0)*CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("RollerB", Vector3.new(.65,.8,.8), CFrame.new(0,-1.35,0)*CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("RollerC", Vector3.new(.65,.8,.8), CFrame.new(0,0,1.35)*CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("RollerD", Vector3.new(.65,.8,.8), CFrame.new(0,0,-1.35)*CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Rubber, "WheelSpinner"),
}, {Category="Mobility", Rarity="Rare", Stackable=false, AttachmentNodes=nodes(Vector3.new(3.8,3.8,2.7)), Mobility={Kind="OmniWheel",Radius=1.7,Drive=true,Steer=false,Grip=.8,LateralGrip=.18,DriveTorque=1050,RollingResistance=.04}, Power={Generation=0,Demand=12}, Controls={"Throttle","Strafe"}}))

add(H.part("SuspensionWheel", "Suspension Wheel", "SUSPENSION", "Wheel on a visible long-travel arm with spring and damper hardware.", Vector3.new(4.2,5.2,3), 57, 390, {
	H.cylinder("Tyre", Vector3.new(1.35,3.6,3.6), CFrame.new(-.55,-.75,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("Rim", Vector3.new(1.5,2.3,2.3), CFrame.new(-.55,-.75,0)*CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.block("SwingArm", Vector3.new(.65,3.2,.7), CFrame.new(.55,.15,0)*CFrame.Angles(0,0,math.rad(-24)), "Mechanical"), H.cylinder("Spring", Vector3.new(.45,.65,.65), CFrame.new(.75,1.25,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"), H.block("TopMount", Vector3.new(1.2,.55,1.4), CFrame.new(.75,2.05,0), "Primary"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(4.2,5.2,3)), Mobility={Kind="Wheel",Radius=1.8,Drive=true,Steer=false,Grip=1.45,DriveTorque=1450,SuspensionTravel=1.1,Spring=19000,Damping=2100,RollingResistance=.06}, Controls={"Throttle"}}))

add(H.part("TrackSprocket", "Track Drive Sprocket", "SPROCKET", "Toothed-looking powered sprocket for tracked and chain-driven builds.", Vector3.new(4,4,2.2), 52, 410, {
	H.cylinder("Outer", Vector3.new(1.6,3.7,3.7), CFrame.Angles(0,0,math.rad(90)), "Primary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("Inner", Vector3.new(1.75,2.3,2.3), CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Metal, "WheelSpinner"), H.cylinder("Hub", Vector3.new(1.9,.9,.9), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Metal, "WheelSpinner"),
	H.block("ToothTop", Vector3.new(1.6,.35,.65), CFrame.new(0,1.85,0), "Accent", Enum.Material.Metal, "WheelSpinner"), H.block("ToothBottom", Vector3.new(1.6,.35,.65), CFrame.new(0,-1.85,0), "Accent", Enum.Material.Metal, "WheelSpinner"), H.block("ToothFront", Vector3.new(1.6,.65,.35), CFrame.new(0,0,-1.85), "Accent", Enum.Material.Metal, "WheelSpinner"), H.block("ToothBack", Vector3.new(1.6,.65,.35), CFrame.new(0,0,1.85), "Accent", Enum.Material.Metal, "WheelSpinner"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(4,4,2.2)), Mobility={Kind="TrackDrive",Radius=1.85,Drive=true,Steer=false,Grip=1.7,DriveTorque=2600,RollingResistance=.085}, Controls={"Throttle"}}))

add(H.part("TrackBogie", "Track Bogie", "BOGIE", "Twin-roadwheel bogie assembly for building long tracked vehicles.", Vector3.new(3,3.8,6), 68, 460, {
	H.block("Carrier", Vector3.new(1,1,5.5), CFrame.new(.65,1,0), "Primary"), H.cylinder("WheelA", Vector3.new(1.2,2.7,2.7), CFrame.new(-.45,-.55,-1.65)*CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"), H.cylinder("WheelB", Vector3.new(1.2,2.7,2.7), CFrame.new(-.45,-.55,1.65)*CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"),
	H.block("Link", Vector3.new(.5,.5,3.4), CFrame.new(-.45,-.55,0), "Accent"), H.cylinder("Pivot", Vector3.new(1.25,.75,.75), CFrame.new(.65,.85,0)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(3,3.8,6)), Mobility={Kind="TrackBogie",Radius=1.35,Drive=false,Steer=false,Grip=1.8,RollingResistance=.09,SuspensionTravel=.6,Spring=24000,Damping=2800}}))

add(H.part("PoweredAxle", "Powered Axle", "AXLE", "Central gearbox and differential intended to feed paired wheel modules.", Vector3.new(5,2.5,3), 46, 350, {
	H.cylinder("Axle", Vector3.new(4.7,.55,.55), CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.block("DiffHousing", Vector3.new(2.1,2.1,2.4), nil, "Primary"), H.cylinder("DiffCap", Vector3.new(.5,1.6,1.6), CFrame.new(0,0,-1.2)*CFrame.Angles(0,math.rad(90),0), "Accent"), H.block("MountL", Vector3.new(.7,.7,1.7), CFrame.new(-1.8,.75,0), "Secondary"), H.block("MountR", Vector3.new(.7,.7,1.7), CFrame.new(1.8,.75,0), "Secondary"),
}, {Category="Mobility", Rarity="Uncommon", Stackable=false, AttachmentNodes=nodes(Vector3.new(5,2.5,3)), Mobility={Kind="Drivetrain",MechanicalDemand=0,TorqueCapacity=4200}, Controls={"Throttle"}}))

add(H.part("CasterWheel", "Caster Wheel", "CASTER", "Small freely swivelling support caster for trailers and strange machines.", Vector3.new(2.4,3,2.4), 12, 130, {
	H.block("Mount", Vector3.new(1.7,.45,1.7), CFrame.new(0,1.2,0), "Primary"), H.cylinder("Swivel", Vector3.new(.45,1,1), CFrame.new(0,.75,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"), H.block("Fork", Vector3.new(.45,1.3,.5), CFrame.new(.35,.05,0), "Mechanical", Enum.Material.Metal, "SteeringVisual"), H.cylinder("Tyre", Vector3.new(.8,1.8,1.8), CFrame.new(-.2,-.8,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary", Enum.Material.Rubber, "WheelSpinner"),
}, {Category="Mobility", AttachmentNodes=nodes(Vector3.new(2.4,3,2.4)), Mobility={Kind="Caster",Radius=.9,Drive=false,Steer=true,FreeCaster=true,Grip=.9,RollingResistance=.035}}))

return parts
