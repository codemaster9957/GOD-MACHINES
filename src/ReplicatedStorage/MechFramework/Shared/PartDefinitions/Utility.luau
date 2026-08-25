--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(def) table.insert(parts, def) end
local function unodes(size) return H.boxNodes(size, "Utility", {"Structural","Utility"}) end

add(H.part("FuelTank", "Fuel Tank", "FUEL", "Cylindrical protected fuel tank with straps, filler cap and pipe outlet.", Vector3.new(4,4,5), 48, 240, {
	H.cylinder("Tank", Vector3.new(4.2,3.4,3.4), CFrame.Angles(0,math.rad(90),0), "Primary"), H.block("StrapA", Vector3.new(.35,3.8,3.8), CFrame.new(0,0,-1.45), "Secondary"), H.block("StrapB", Vector3.new(.35,3.8,3.8), CFrame.new(0,0,1.45), "Secondary"), H.cylinder("Cap", Vector3.new(.5,.65,.65), CFrame.new(0,1.75,-1)*CFrame.Angles(0,0,math.rad(90)), "Accent"), H.cylinder("Outlet", Vector3.new(.7,.45,.45), CFrame.new(1.75,-1,1)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="Utility", Stackable=false, AttachmentNodes=unodes(Vector3.new(4,4,5)), Fuel={Type="Liquid",Capacity=220,Amount=220}, Utility={Kind="FuelTank"}}))

add(H.part("AmmoCrate", "Ammo Crate", "AMMO", "Reinforced ammunition locker with latches and hazard stripe trim.", Vector3.new(4,3,4), 66, 260, {
	H.block("Box", Vector3.new(3.8,2.8,3.8), nil, "Primary"), H.block("Lid", Vector3.new(3.9,.35,3.9), CFrame.new(0,1.4,0), "Secondary"), H.block("LatchL", Vector3.new(.5,.7,.25), CFrame.new(-1,.3,-1.95), "Accent"), H.block("LatchR", Vector3.new(.5,.7,.25), CFrame.new(1,.3,-1.95), "Accent"), H.block("StripeA", Vector3.new(.25,.25,2.7), CFrame.new(-.5,1.62,0)*CFrame.Angles(0,math.rad(35),0), "Accent"), H.block("StripeB", Vector3.new(.25,.25,2.7), CFrame.new(.5,1.62,0)*CFrame.Angles(0,math.rad(35),0), "Accent"),
}, {Category="Utility", Stackable=false, AttachmentNodes=unodes(Vector3.new(4,3,4)), Utility={Kind="AmmoStorage",Capacity=160}}))

add(H.part("CargoBox", "Cargo Box", "CARGO", "Large utility container with ribbed sides and tie-down rails.", Vector3.new(5,4,6), 72, 320, {
	H.block("Container", Vector3.new(4.8,3.8,5.8), nil, "Primary"), H.block("Rib1", Vector3.new(5,.3,.35), CFrame.new(0,1.55,-1.8), "Secondary"), H.block("Rib2", Vector3.new(5,.3,.35), CFrame.new(0,1.55,0), "Secondary"), H.block("Rib3", Vector3.new(5,.3,.35), CFrame.new(0,1.55,1.8), "Secondary"), H.block("DoorLine", Vector3.new(3.5,.2,.15), CFrame.new(0,0,-2.95), "Accent"), H.block("Handle", Vector3.new(1,.25,.2), CFrame.new(0,-.6,-3.05), "Mechanical"),
}, {Category="Utility", AttachmentNodes=unodes(Vector3.new(5,4,6)), Utility={Kind="Cargo",Capacity=24}}))

add(H.part("BallastBlock", "Ballast Block", "BALLAST", "Dense low-mounted weight with lifting eyes for tuning centre of mass.", Vector3.new(4,2.5,4), 180, 420, {
	H.block("Mass", Vector3.new(3.8,2.2,3.8), nil, "Secondary"), H.block("TopPlate", Vector3.new(3.9,.35,3.9), CFrame.new(0,1.15,0), "Primary"), H.cylinder("EyeL", Vector3.new(.45,.9,.9), CFrame.new(-1.15,1.45,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"), H.cylinder("EyeR", Vector3.new(.45,.9,.9), CFrame.new(1.15,1.45,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"),
}, {Category="Utility", AttachmentNodes=unodes(Vector3.new(4,2.5,4)), Utility={Kind="Ballast"}, PhysicalProperties={Density=7,StructuralStrength=700}}))

add(H.part("SensorMast", "Sensor Mast", "SENSOR", "Tall rotating sensor cluster with radar dish, optics and antenna whiskers.", Vector3.new(3.5,6,3.5), 31, 170, {
	H.block("Base", Vector3.new(2.6,.8,2.6), CFrame.new(0,-2.5,0), "Primary"), H.cylinder("Mast", Vector3.new(4.3,.45,.45), CFrame.Angles(0,0,math.rad(90)), "Secondary"), H.cylinder("Radar", Vector3.new(.35,2.6,2.6), CFrame.new(0,1.35,0)*CFrame.Angles(0,math.rad(90),0), "Primary", Enum.Material.Metal, "SensorSpinner"), H.wedge("DishFace", Vector3.new(2.4,1.2,.45), CFrame.new(0,1.35,-.5)*CFrame.Angles(math.rad(-20),0,0), "Accent"), H.glass("Optic", Vector3.new(.8,.6,.35), CFrame.new(.85,.3,-.3), "Glass"), H.cylinder("Antenna", Vector3.new(1.6,.15,.15), CFrame.new(-.8,2.4,0)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="Utility", Rarity="Uncommon", Stackable=false, AttachmentNodes=unodes(Vector3.new(3.5,6,3.5)), Power={Generation=0,Demand=6,Priority=50}, Utility={Kind="Sensor",Range=1800}}))

add(H.part("Spotlight", "Spotlight", "LIGHT", "Armoured directional floodlight with glass lens and mounting yoke.", Vector3.new(3,3,3.5), 19, 130, {
	H.block("Yoke", Vector3.new(2.7,.45,1.2), CFrame.new(0,-1,.4), "Primary"), H.cylinder("Lamp", Vector3.new(2.2,2.3,2.3), CFrame.new(0,.15,-.25)*CFrame.Angles(0,math.rad(90),0), "Secondary"), H.glass("Lens", Vector3.new(2.1,2.1,.2), CFrame.new(0,.15,-1.4), "Glass"), H.cylinder("PivotL", Vector3.new(.45,.55,.55), CFrame.new(-1.25,0,.2)*CFrame.Angles(0,0,math.rad(90)), "Accent"), H.cylinder("PivotR", Vector3.new(.45,.55,.55), CFrame.new(1.25,0,.2)*CFrame.Angles(0,0,math.rad(90)), "Accent"),
}, {Category="Utility", AttachmentNodes=unodes(Vector3.new(3,3,3.5)), Power={Generation=0,Demand=3,Priority=80}, Utility={Kind="Spotlight",Brightness=4,Range=70}, Controls={"Utility"}}))

return parts
