--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}

local function add(def) table.insert(parts, def) end

add(H.part("StructuralFrame", "Structural Frame", "FRAME", "Structural", "Balanced four-post chassis frame with an open mechanical core.", Vector3.new(4,2,4), 20, 250, {
	H.block("TopRail", Vector3.new(4,.35,.45), CFrame.new(0,.75,-1.45), "Primary"), H.block("BottomRail", Vector3.new(4,.35,.45), CFrame.new(0,-.75,1.45), "Primary"),
	H.block("LeftRail", Vector3.new(.45,1.7,3), CFrame.new(-1.65,0,0), "Secondary"), H.block("RightRail", Vector3.new(.45,1.7,3), CFrame.new(1.65,0,0), "Secondary"),
	H.block("Cross", Vector3.new(3.2,.25,.35), CFrame.Angles(0,math.rad(45),0), "Accent"), H.block("Cross2", Vector3.new(3.2,.25,.35), CFrame.Angles(0,math.rad(-45),0), "Accent"),
}))

add(H.part("CompactFrame", "Compact Frame", "COMPACT", "Structural", "Dense cube-frame for small machines and internal reinforcement.", Vector3.new(3,3,3), 24, 290, {
	H.block("Core", Vector3.new(1.1,1.1,1.1), nil, "Secondary"), H.block("X", Vector3.new(3,.3,.3), nil, "Primary"), H.block("Y", Vector3.new(.3,3,.3), nil, "Primary"), H.block("Z", Vector3.new(.3,.3,3), nil, "Primary"),
	H.ball("Hub", Vector3.new(.8,.8,.8), nil, "Accent"),
}))

add(H.part("HeavyFrame", "Heavy Frame", "HEAVY", "Structural", "Overbuilt chassis cell with layered rails for tanks and siege machines.", Vector3.new(5,3,5), 58, 520, {
	H.block("Deck", Vector3.new(5,.55,5), CFrame.new(0,-1.15,0), "Primary"), H.block("Spine", Vector3.new(1.1,2.3,4.6), nil, "Secondary"),
	H.block("LeftGirder", Vector3.new(.7,2.5,4.5), CFrame.new(-2,0,0), "Primary"), H.block("RightGirder", Vector3.new(.7,2.5,4.5), CFrame.new(2,0,0), "Primary"),
	H.block("FrontBrace", Vector3.new(3.5,.45,.65), CFrame.new(0,.9,-2), "Accent"), H.block("RearBrace", Vector3.new(3.5,.45,.65), CFrame.new(0,.9,2), "Accent"),
}))

add(H.part("TriTruss", "Triangular Truss", "TRI TRUSS", "Structural", "Triangular structural truss that saves mass while resisting bending.", Vector3.new(5,3,2), 22, 260, {
	H.block("Base", Vector3.new(5,.35,.45), CFrame.new(0,-1.25,0), "Primary"),
	H.block("LeftDiag", Vector3.new(.38,3.8,.42), CFrame.new(-1.25,0,0)*CFrame.Angles(0,0,math.rad(-52)), "Primary"),
	H.block("RightDiag", Vector3.new(.38,3.8,.42), CFrame.new(1.25,0,0)*CFrame.Angles(0,0,math.rad(52)), "Primary"),
	H.cylinder("ApexHub", Vector3.new(.55,.8,.8), CFrame.new(0,1.15,0), "Accent"),
}))

add(H.part("CrossJunction", "Cross Junction", "CROSS", "Structural", "Six-way reinforced junction for branching frames in every direction.", Vector3.new(3.5,3.5,3.5), 31, 340, {
	H.block("XBeam", Vector3.new(3.5,.7,.7), nil, "Primary"), H.block("YBeam", Vector3.new(.7,3.5,.7), nil, "Primary"), H.block("ZBeam", Vector3.new(.7,.7,3.5), nil, "Primary"),
	H.ball("CenterHub", Vector3.new(1.4,1.4,1.4), nil, "Secondary"), H.cylinder("RingX", Vector3.new(.25,1.8,1.8), nil, "Accent"),
}))

add(H.part("HexHub", "Hexagonal Hub", "HEX HUB", "Structural", "Compact rounded junction inspired by industrial robot knuckles.", Vector3.new(3,3,3), 34, 360, {
	H.cylinder("Body", Vector3.new(2.2,2.6,2.6), CFrame.Angles(0,0,math.rad(90)), "Primary"),
	H.cylinder("CollarA", Vector3.new(.45,3,3), CFrame.new(-1.15,0,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary"), H.cylinder("CollarB", Vector3.new(.45,3,3), CFrame.new(1.15,0,0)*CFrame.Angles(0,0,math.rad(90)), "Secondary"),
	H.block("TopKey", Vector3.new(1.1,.4,1.1), CFrame.new(0,1.35,0), "Accent"), H.block("BottomKey", Vector3.new(1.1,.4,1.1), CFrame.new(0,-1.35,0), "Accent"),
}))

add(H.part("SpineBeam", "Spine Beam", "SPINE", "Structural", "Long enclosed backbone with segmented ribs for large machines.", Vector3.new(3,3,7), 42, 430, {
	H.block("Spine", Vector3.new(1.2,1.2,7), nil, "Secondary"), H.block("TopRail", Vector3.new(2.5,.35,6.6), CFrame.new(0,1.15,0), "Primary"), H.block("BottomRail", Vector3.new(2.5,.35,6.6), CFrame.new(0,-1.15,0), "Primary"),
	H.block("Rib1", Vector3.new(2.9,2.7,.35), CFrame.new(0,0,-2.2), "Accent"), H.block("Rib2", Vector3.new(2.9,2.7,.35), nil, "Accent"), H.block("Rib3", Vector3.new(2.9,2.7,.35), CFrame.new(0,0,2.2), "Accent"),
}))

add(H.part("LatticeBeam", "Lattice Beam", "LATTICE", "Structural", "Open lightweight beam with repeating diagonal webbing.", Vector3.new(3,3,8), 27, 300, {
	H.block("Top", Vector3.new(.35,.35,8), CFrame.new(0,1.15,0), "Primary"), H.block("Bottom", Vector3.new(.35,.35,8), CFrame.new(0,-1.15,0), "Primary"),
	H.block("Diag1", Vector3.new(.3,2.7,.35), CFrame.new(0,0,-2.8)*CFrame.Angles(math.rad(40),0,0), "Accent"), H.block("Diag2", Vector3.new(.3,2.7,.35), CFrame.new(0,0,-.9)*CFrame.Angles(math.rad(-40),0,0), "Accent"), H.block("Diag3", Vector3.new(.3,2.7,.35), CFrame.new(0,0,.9)*CFrame.Angles(math.rad(40),0,0), "Accent"), H.block("Diag4", Vector3.new(.3,2.7,.35), CFrame.new(0,0,2.8)*CFrame.Angles(math.rad(-40),0,0), "Accent"),
}))

add(H.part("CornerBrace", "Corner Brace", "CORNER", "Structural", "Triangular ninety-degree brace for reinforcing stressed corners.", Vector3.new(4,4,2), 19, 240, {
	H.block("Vertical", Vector3.new(.65,4,1.5), CFrame.new(-1.55,0,0), "Primary"), H.block("Horizontal", Vector3.new(4,.65,1.5), CFrame.new(0,-1.55,0), "Primary"),
	H.block("Diagonal", Vector3.new(.6,4.6,1), CFrame.Angles(0,0,math.rad(-45)), "Accent"), H.cornerWedge("Gusset", Vector3.new(1.6,1.6,1.4), CFrame.new(-1.1,-1.1,0), "Secondary"),
}))

add(H.part("TBrace", "T Brace", "T BRACE", "Structural", "T-shaped load spreader for decks, towers and weapon mounts.", Vector3.new(5,4,2), 23, 280, {
	H.block("Cap", Vector3.new(5,.7,1.4), CFrame.new(0,1.55,0), "Primary"), H.block("Stem", Vector3.new(.8,3.5,1.4), CFrame.new(0,-.25,0), "Primary"),
	H.wedge("LeftGusset", Vector3.new(1.6,1.6,1.2), CFrame.new(-1.15,.65,0)*CFrame.Angles(0,math.pi,0), "Accent"), H.wedge("RightGusset", Vector3.new(1.6,1.6,1.2), CFrame.new(1.15,.65,0), "Accent"),
}))

add(H.part("XBrace", "X Brace", "X BRACE", "Structural", "Cross-braced panel that resists twisting without filling the whole volume.", Vector3.new(5,5,1.5), 25, 310, {
	H.block("DiagA", Vector3.new(.6,6.4,.7), CFrame.Angles(0,0,math.rad(45)), "Primary"), H.block("DiagB", Vector3.new(.6,6.4,.7), CFrame.Angles(0,0,math.rad(-45)), "Primary"),
	H.cylinder("CenterPin", Vector3.new(.5,1.2,1.2), CFrame.Angles(0,math.rad(90),0), "Accent"), H.block("EdgeTop", Vector3.new(4.5,.3,.4), CFrame.new(0,2.25,0), "Secondary"), H.block("EdgeBottom", Vector3.new(4.5,.3,.4), CFrame.new(0,-2.25,0), "Secondary"),
}))

add(H.part("TowerFrame", "Tower Frame", "TOWER", "Structural", "Tall cage frame for walkers, cranes and vertical reactor stacks.", Vector3.new(4,7,4), 46, 420, {
	H.block("Post1", Vector3.new(.5,7,.5), CFrame.new(-1.5,0,-1.5), "Primary"), H.block("Post2", Vector3.new(.5,7,.5), CFrame.new(1.5,0,-1.5), "Primary"), H.block("Post3", Vector3.new(.5,7,.5), CFrame.new(-1.5,0,1.5), "Primary"), H.block("Post4", Vector3.new(.5,7,.5), CFrame.new(1.5,0,1.5), "Primary"),
	H.block("MidRing", Vector3.new(3.6,.4,3.6), nil, "Accent"), H.block("TopRing", Vector3.new(3.6,.4,3.6), CFrame.new(0,3.2,0), "Secondary"), H.block("BottomRing", Vector3.new(3.6,.4,3.6), CFrame.new(0,-3.2,0), "Secondary"),
}))

add(H.part("RingFrame", "Ring Frame", "RING", "Structural", "Circular-looking octagonal frame for turbines, rotors and central hubs.", Vector3.new(5,5,2), 29, 300, {
	H.block("Top", Vector3.new(2.8,.45,.7), CFrame.new(0,2,0), "Primary"), H.block("Bottom", Vector3.new(2.8,.45,.7), CFrame.new(0,-2,0), "Primary"), H.block("Left", Vector3.new(.45,2.8,.7), CFrame.new(-2,0,0), "Primary"), H.block("Right", Vector3.new(.45,2.8,.7), CFrame.new(2,0,0), "Primary"),
	H.block("NE", Vector3.new(.42,2.2,.7), CFrame.new(1.4,1.4,0)*CFrame.Angles(0,0,math.rad(45)), "Accent"), H.block("NW", Vector3.new(.42,2.2,.7), CFrame.new(-1.4,1.4,0)*CFrame.Angles(0,0,math.rad(-45)), "Accent"), H.block("SE", Vector3.new(.42,2.2,.7), CFrame.new(1.4,-1.4,0)*CFrame.Angles(0,0,math.rad(-45)), "Accent"), H.block("SW", Vector3.new(.42,2.2,.7), CFrame.new(-1.4,-1.4,0)*CFrame.Angles(0,0,math.rad(45)), "Accent"),
}))

add(H.part("SkidFrame", "Skid Frame", "SKID", "Structural", "Low sled-like base with angled skids for rough landing and sliding craft.", Vector3.new(5,2.5,6), 35, 340, {
	H.block("Deck", Vector3.new(4.5,.45,5.3), CFrame.new(0,.65,0), "Primary"), H.block("LeftSkid", Vector3.new(.65,.6,6), CFrame.new(-1.75,-.8,0), "Secondary"), H.block("RightSkid", Vector3.new(.65,.6,6), CFrame.new(1.75,-.8,0), "Secondary"),
	H.wedge("NoseL", Vector3.new(.65,.8,1.2), CFrame.new(-1.75,-.55,-2.7)*CFrame.Angles(0,math.pi,0), "Accent"), H.wedge("NoseR", Vector3.new(.65,.8,1.2), CFrame.new(1.75,-.55,-2.7)*CFrame.Angles(0,math.pi,0), "Accent"),
}))

add(H.part("SuspensionMount", "Suspension Mount", "SUSP MOUNT", "Structural", "Reinforced arched hardpoint built to carry wheel and suspension loads.", Vector3.new(4,4,2.5), 38, 390, {
	H.block("Backplate", Vector3.new(3.8,3.8,.6), CFrame.new(0,0,.75), "Secondary"), H.cylinder("Pivot", Vector3.new(1,2.2,2.2), CFrame.new(0,-.4,-.45), "Mechanical"),
	H.block("LeftFork", Vector3.new(.6,3,1), CFrame.new(-1.4,.25,-.3), "Primary"), H.block("RightFork", Vector3.new(.6,3,1), CFrame.new(1.4,.25,-.3), "Primary"), H.block("TopBridge", Vector3.new(3.4,.6,1), CFrame.new(0,1.45,-.3), "Accent"),
}, {AttachmentNodes = H.boxNodes(Vector3.new(4,4,2.5), "Mobility")}))

add(H.part("HingeMount", "Hinge Mount", "HINGE", "Structural", "Twin-lug pivot mount for articulated builds and future mechanisms.", Vector3.new(3,3,3), 30, 320, {
	H.block("Base", Vector3.new(3,.7,3), CFrame.new(0,-1.1,0), "Primary"), H.block("LugL", Vector3.new(.65,2.2,1.2), CFrame.new(-.9,.3,0), "Primary"), H.block("LugR", Vector3.new(.65,2.2,1.2), CFrame.new(.9,.3,0), "Primary"),
	H.cylinder("Pin", Vector3.new(2.6,.7,.7), CFrame.new(0,.45,0), "Accent"),
}))

add(H.part("UniversalMount", "Universal Mount", "UNI MOUNT", "Structural", "Multi-axis hardpoint with concentric collars for awkward attachments.", Vector3.new(3.5,3.5,3.5), 37, 350, {
	H.ball("Core", Vector3.new(2.3,2.3,2.3), nil, "Secondary"), H.cylinder("RingX", Vector3.new(.35,3.1,3.1), nil, "Primary"), H.cylinder("RingY", Vector3.new(.35,3.1,3.1), CFrame.Angles(0,0,math.rad(90)), "Primary"),
	H.block("KeyTop", Vector3.new(.7,.7,1.6), CFrame.new(0,1.45,0), "Accent"), H.block("KeyFront", Vector3.new(.7,1.6,.7), CFrame.new(0,0,-1.45), "Accent"),
}))

add(H.part("KeelFrame", "Keel Frame", "KEEL", "Structural", "Boat-and-aircraft style central keel with a tapered lower spine.", Vector3.new(4,4,8), 44, 410, {
	H.block("UpperSpine", Vector3.new(2.2,1.2,7.5), CFrame.new(0,.8,0), "Primary"), H.wedge("LowerKeel", Vector3.new(2.4,2.4,7.2), CFrame.new(0,-.9,0)*CFrame.Angles(math.rad(90),0,0), "Secondary"),
	H.block("RibA", Vector3.new(4,.35,.5), CFrame.new(0,.4,-2.4), "Accent"), H.block("RibB", Vector3.new(4,.35,.5), CFrame.new(0,.4,0), "Accent"), H.block("RibC", Vector3.new(4,.35,.5), CFrame.new(0,.4,2.4), "Accent"),
}))

return parts
