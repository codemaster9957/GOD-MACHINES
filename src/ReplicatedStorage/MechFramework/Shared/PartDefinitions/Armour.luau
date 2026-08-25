--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(def) table.insert(parts, def) end

add(H.part("LightArmourPlate", "Light Armour Plate", "LIGHT PLATE", "Thin stamped plate with pressed ribs for cheap broad protection.", Vector3.new(5,.7,4), 24, 280, {
	H.block("Plate", Vector3.new(5,.45,4), nil, "Primary"), H.block("RibL", Vector3.new(.35,.65,3.4), CFrame.new(-1.55,.2,0), "Secondary"), H.block("RibR", Vector3.new(.35,.65,3.4), CFrame.new(1.55,.2,0), "Secondary"), H.block("RibC", Vector3.new(2.5,.68,.3), CFrame.new(0,.2,0), "Accent"),
}, {Category="Armour", Rarity="Common", PhysicalProperties={Density=1.2,StructuralStrength=420}}))

add(H.part("HeavyArmourPlate", "Heavy Armour Plate", "HEAVY PLATE", "Layered slab with a sacrificial outer face and recessed centre.", Vector3.new(5,1.3,4), 62, 620, {
	H.block("Backing", Vector3.new(5,1,4), CFrame.new(0,-.12,0), "Secondary"), H.block("Face", Vector3.new(4.3,.55,3.3), CFrame.new(0,.5,0), "Primary"), H.block("TopBand", Vector3.new(4.7,.35,.45), CFrame.new(0,.65,-1.7), "Accent"), H.block("BottomBand", Vector3.new(4.7,.35,.45), CFrame.new(0,.65,1.7), "Accent"),
}, {Category="Armour", Rarity="Uncommon", Stackable=false, PhysicalProperties={Density=2.3,StructuralStrength=850}}))

add(H.part("SlopedArmour", "Sloped Armour", "SLOPE", "Angled glacis plate that creates a distinctly tank-like wedge profile.", Vector3.new(5,2,4), 49, 520, {
	H.wedge("Glacis", Vector3.new(5,2,4), CFrame.Angles(0,math.pi,0), "Primary"), H.block("LowerLip", Vector3.new(5,.35,.65), CFrame.new(0,-.75,1.55), "Secondary"), H.block("SightStrip", Vector3.new(2.5,.18,.25), CFrame.new(0,.6,-1.4), "Accent"),
}, {Category="Armour", Rarity="Uncommon", Stackable=false, PhysicalProperties={Density=1.9,StructuralStrength=720}}))

add(H.part("WedgeNose", "Wedge Nose", "NOSE", "Pointed prow for fast vehicles, aircraft and battering machines.", Vector3.new(5,2.6,5), 42, 450, {
	H.wedge("LeftCheek", Vector3.new(2.6,2.4,5), CFrame.new(-1.2,0,0)*CFrame.Angles(0,math.rad(90),0), "Primary"), H.wedge("RightCheek", Vector3.new(2.6,2.4,5), CFrame.new(1.2,0,0)*CFrame.Angles(0,math.rad(-90),0), "Primary"), H.block("Spine", Vector3.new(.45,.55,4.3), CFrame.new(0,.85,0), "Accent"),
}, {Category="Armour", PhysicalProperties={Density=1.5,StructuralStrength=600}}))

add(H.part("CurvedShield", "Curved Shield", "CURVED", "Segmented rounded shield built from an armoured centre and curved-looking cheeks.", Vector3.new(5,3.5,2), 45, 500, {
	H.block("Center", Vector3.new(2.4,3.2,.75), CFrame.new(0,0,-.3), "Primary"), H.cornerWedge("CheekL", Vector3.new(1.5,3.2,1.4), CFrame.new(-1.85,0,0)*CFrame.Angles(0,math.rad(-90),0), "Primary"), H.cornerWedge("CheekR", Vector3.new(1.5,3.2,1.4), CFrame.new(1.85,0,0)*CFrame.Angles(0,math.rad(90),0), "Primary"), H.block("Band", Vector3.new(4.5,.35,.45), CFrame.new(0,0.95,-.75), "Accent"),
}, {Category="Armour", Rarity="Uncommon", Stackable=false}))

add(H.part("SideSkirt", "Armour Side Skirt", "SIDE SKIRT", "Long segmented side protection designed to hang over wheels and tracks.", Vector3.new(2,4,7), 38, 410, {
	H.block("Rail", Vector3.new(.55,3.6,6.8), CFrame.new(.55,0,0), "Secondary"), H.block("Panel1", Vector3.new(.5,3.1,1.8), CFrame.new(-.3,0,-2.25), "Primary"), H.block("Panel2", Vector3.new(.5,3.1,1.8), CFrame.new(-.3,0,0), "Primary"), H.block("Panel3", Vector3.new(.5,3.1,1.8), CFrame.new(-.3,0,2.25), "Primary"), H.block("TopStrip", Vector3.new(.75,.35,6.5), CFrame.new(-.05,1.55,0), "Accent"),
}, {Category="Armour"}))

add(H.part("ReinforcedCorner", "Reinforced Corner", "ARM CORNER", "Boxed armour corner with a chamfered impact cap.", Vector3.new(3,3,3), 34, 430, {
	H.block("BlockA", Vector3.new(2.7,2.7,1.2), CFrame.new(0,0,.7), "Primary"), H.block("BlockB", Vector3.new(1.2,2.7,2.7), CFrame.new(.7,0,0), "Primary"), H.cornerWedge("Cap", Vector3.new(1.8,2.8,1.8), CFrame.new(-.5,0,-.5)*CFrame.Angles(0,math.pi,0), "Secondary"), H.block("BoltBand", Vector3.new(.25,2.2,2.2), CFrame.new(1.35,0,0), "Accent"),
}, {Category="Armour"}))

add(H.part("BlastPlate", "Blast Plate", "BLAST", "Spaced armour with a thin sacrificial face separated from the backing slab.", Vector3.new(5,1.8,4), 53, 560, {
	H.block("Backing", Vector3.new(5,.7,4), CFrame.new(0,-.45,0), "Secondary"), H.block("Face", Vector3.new(4.6,.35,3.6), CFrame.new(0,.55,0), "Primary"), H.cylinder("Spacer1", Vector3.new(.8,.3,.3), CFrame.new(-1.6,.05,-1.2)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.cylinder("Spacer2", Vector3.new(.8,.3,.3), CFrame.new(1.6,.05,-1.2)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.cylinder("Spacer3", Vector3.new(.8,.3,.3), CFrame.new(-1.6,.05,1.2)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.cylinder("Spacer4", Vector3.new(.8,.3,.3), CFrame.new(1.6,.05,1.2)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="Armour", Rarity="Rare", Stackable=false}))

add(H.part("CompositeShell", "Composite Shell", "COMPOSITE", "Layered rounded shell with a central ceramic-looking strike face.", Vector3.new(5,2.2,4), 41, 590, {
	H.wedge("ShellL", Vector3.new(2.55,2,4), CFrame.new(-1.15,0,0)*CFrame.Angles(0,0,math.rad(6)), "Primary"), H.wedge("ShellR", Vector3.new(2.55,2,4), CFrame.new(1.15,0,0)*CFrame.Angles(0,math.pi,math.rad(-6)), "Primary"), H.block("StrikeFace", Vector3.new(2.2,.4,2.7), CFrame.new(0,.85,0), "Secondary"), H.block("EdgeTrim", Vector3.new(4.3,.25,.35), CFrame.new(0,1,-1.65), "Accent"),
}, {Category="Armour", Rarity="Rare", Stackable=false, PhysicalProperties={Density=1.4,StructuralStrength=900}}))

add(H.part("ArmourCupola", "Armour Cupola", "CUPOLA", "Low circular armoured observation dome for vehicle roofs.", Vector3.new(4,2.5,4), 47, 480, {
	H.cylinder("BaseRing", Vector3.new(.7,3.8,3.8), CFrame.new(0,-.85,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary"), H.cylinder("Drum", Vector3.new(1.4,3.2,3.2), CFrame.Angles(0,0,math.rad(90)), "Primary"), H.ball("Dome", Vector3.new(2.7,1.5,2.7), CFrame.new(0,.75,0), "Primary"), H.glass("Vision", Vector3.new(2.4,.35,.18), CFrame.new(0,.4,-1.45), "Glass"), H.block("Latch", Vector3.new(.5,.25,.9), CFrame.new(0,1.1,.3), "Accent"),
}, {Category="Armour", Rarity="Uncommon", Stackable=false}))

add(H.part("BellyPlate", "Belly Plate", "BELLY", "Shallow V-shaped underside armour for protecting low-slung vehicles.", Vector3.new(5,2,5), 51, 530, {
	H.wedge("LeftV", Vector3.new(2.7,1.8,5), CFrame.new(-1.2,0,0)*CFrame.Angles(0,0,math.rad(20)), "Primary"), H.wedge("RightV", Vector3.new(2.7,1.8,5), CFrame.new(1.2,0,0)*CFrame.Angles(0,math.pi,math.rad(-20)), "Primary"), H.block("KeelStrip", Vector3.new(.45,.45,4.6), CFrame.new(0,-.75,0), "Accent"),
}, {Category="Armour"}))

add(H.part("RamPlate", "Ram Plate", "RAM PLATE", "Massive toothed impact plate built to survive deliberate collisions.", Vector3.new(5,3.5,3), 74, 700, {
	H.wedge("Main", Vector3.new(5,3.2,2.8), CFrame.Angles(math.rad(90),0,0), "Primary"), H.block("Backer", Vector3.new(4.8,2.8,.7), CFrame.new(0,0,1), "Secondary"), H.wedge("ToothL", Vector3.new(1.1,1.2,1.6), CFrame.new(-1.6,-1.25,-.9), "Accent"), H.wedge("ToothC", Vector3.new(1.1,1.2,1.8), CFrame.new(0,-1.25,-1), "Accent"), H.wedge("ToothR", Vector3.new(1.1,1.2,1.6), CFrame.new(1.6,-1.25,-.9), "Accent"),
}, {Category="Armour", Rarity="Uncommon", Stackable=false, PhysicalProperties={Density=2.6,StructuralStrength=1100}}))

return parts
