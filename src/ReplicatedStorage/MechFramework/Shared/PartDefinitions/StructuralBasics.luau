--!strict
-- Phase 2 general-purpose construction primitives. Intentionally simple, modular and node-rich.

local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(definition) table.insert(parts, definition) end

local studSize = Vector3.new(2,2,2)
add(H.part("StudBlock", "Stud Block", "STUD", "Universal compact cube for fast chassis blocking, spacing and prototyping.", studSize, 11, 165, {
	H.block("Body", Vector3.new(1.92,1.92,1.92), nil, "Primary"),
	H.block("Inset", Vector3.new(1.35,.12,1.35), CFrame.new(0,.96,0), "Secondary"),
	H.cylinder("TopStud", Vector3.new(.14,.62,.62), CFrame.new(0,1.04,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"),
}, {
	AttachmentNodes=H.boxNodes(studSize,"Structural"),
	Rarity="Common",
	Tags={"Starter","Structure","Cube"},
}))

local halfSize = Vector3.new(2,1,2)
add(H.part("HalfStudBlock", "Half Stud Block", "HALF STUD", "Half-height universal block for floors, offsets and compact structural shaping.", halfSize, 6, 100, {
	H.block("Body", Vector3.new(1.92,.92,1.92), nil, "Primary"),
	H.block("TopInset", Vector3.new(1.4,.1,1.4), CFrame.new(0,.46,0), "Secondary"),
}, {
	AttachmentNodes=H.boxNodes(halfSize,"Structural"),
	Rarity="Common",
	Tags={"Starter","Structure","Plate"},
}))

local beamSize = Vector3.new(2,2,6)
add(H.part("LongStudBeam", "Long Stud Beam", "STUD BEAM", "Long simple beam with repeated side and top hardpoints for practical chassis construction.", beamSize, 24, 285, {
	H.block("Beam", Vector3.new(1.9,1.9,5.9), nil, "Primary"),
	H.block("Spine", Vector3.new(.35,.2,5.4), CFrame.new(0,.96,0), "Accent"),
	H.block("LowerSpine", Vector3.new(.35,.16,5.4), CFrame.new(0,-.96,0), "Secondary"),
}, {
	AttachmentNodes=H.mergeNodes(
		H.boxNodes(beamSize,"Structural"),
		H.faceGridNodes(beamSize,"Left",1,3,"Structural",nil,"LeftRail"),
		H.faceGridNodes(beamSize,"Right",1,3,"Structural",nil,"RightRail"),
		H.faceGridNodes(beamSize,"Top",3,1,"Structural",nil,"TopRail"),
		H.faceGridNodes(beamSize,"Bottom",3,1,"Structural",nil,"BottomRail")
	),
	Rarity="Common",
	Tags={"Starter","Structure","Beam"},
}))

local plateSize = Vector3.new(4,.5,4)
add(H.part("StructuralPlate", "Structural Plate", "PLATE", "Thin square deck plate with distributed hardpoints for floors, armour backing and mounting bays.", plateSize, 14, 175, {
	H.block("Deck", Vector3.new(3.92,.42,3.92), nil, "Primary"),
	H.block("CrossX", Vector3.new(3.5,.08,.28), CFrame.new(0,.23,0), "Accent"),
	H.block("CrossZ", Vector3.new(.28,.08,3.5), CFrame.new(0,.23,0), "Accent"),
}, {
	AttachmentNodes=H.mergeNodes(
		H.boxNodes(plateSize,"Structural"),
		H.faceGridNodes(plateSize,"Top",3,3,"Structural",nil,"DeckTop"),
		H.faceGridNodes(plateSize,"Bottom",3,3,"Structural",nil,"DeckBottom")
	),
	Rarity="Common",
	Tags={"Starter","Structure","Plate"},
}))

local cornerSize = Vector3.new(3,3,3)
add(H.part("CornerBlock", "Corner Block", "CORNER CELL", "Rigid L-profile structural cell for clean ninety-degree chassis corners without overlapping beams.", cornerSize, 20, 255, {
	H.block("Vertical", Vector3.new(.9,2.9,2.9), CFrame.new(-1.02,0,0), "Primary"),
	H.block("Horizontal", Vector3.new(2.9,.9,2.9), CFrame.new(0,-1.02,0), "Primary"),
	H.cornerWedge("Gusset", Vector3.new(1.8,1.8,2.5), CFrame.new(-.45,-.45,0), "Secondary"),
	H.block("CornerKey", Vector3.new(.28,.28,2.4), CFrame.new(-.78,-.78,0), "Accent"),
}, {
	AttachmentNodes=H.boxNodes(cornerSize,"Structural"),
	Rarity="Common",
	Tags={"Starter","Structure","Corner"},
}))

local triangleSize = Vector3.new(4,3,3)
add(H.part("TriangularBlock", "Triangular Block", "TRI BLOCK", "Wedge-truss structural filler for noses, ramps and angled load paths.", triangleSize, 18, 230, {
	H.wedge("Shell", Vector3.new(3.9,2.9,2.9), nil, "Primary"),
	H.block("BaseRail", Vector3.new(3.7,.35,2.5), CFrame.new(0,-1.25,0), "Secondary"),
	H.block("Brace", Vector3.new(.35,3.8,.45), CFrame.Angles(0,0,math.rad(-52)), "Accent"),
}, {
	AttachmentNodes=H.boxNodes(triangleSize,"Structural"),
	Rarity="Common",
	Tags={"Starter","Structure","Wedge"},
}))

local roundSize = Vector3.new(3,3,3)
add(H.part("RoundStructuralCell", "Round Structural Cell", "ROUND CELL", "Cylindrical structural hub for rotor centres, towers, rounded frames and compact junctions.", roundSize, 23, 280, {
	H.cylinder("Drum", Vector3.new(2.75,2.75,2.75), CFrame.Angles(0,0,math.rad(90)), "Primary"),
	H.cylinder("BandA", Vector3.new(.25,3,3), CFrame.new(-.92,0,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary"),
	H.cylinder("BandB", Vector3.new(.25,3,3), CFrame.new(.92,0,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary"),
	H.block("IndexKey", Vector3.new(.5,.35,1.1), CFrame.new(0,1.42,0), "Accent"),
}, {
	AttachmentNodes=H.boxNodes(roundSize,"Structural"),
	Rarity="Common",
	Tags={"Starter","Structure","Round"},
}))

return table.freeze(parts)
