--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(def) table.insert(parts, def) end
local function anodes(size) return H.boxNodes(size, "Aero", {"Structural","Aero"}) end

add(H.part("StraightWing", "Straight Wing", "WING", "Broad straight wing with spar, tapered tip and visible control hinge.", Vector3.new(8,1.2,4), 32, 220, {
	H.wedge("Main", Vector3.new(7.6,.65,3.7), CFrame.Angles(0,math.rad(90),0), "Primary"), H.block("Spar", Vector3.new(7.2,.35,.5), CFrame.new(0,.15,.35), "Secondary"), H.wedge("Tip", Vector3.new(1.3,.55,2.6), CFrame.new(3.35,0,.2)*CFrame.Angles(0,math.rad(-90),0), "Accent"), H.block("Hinge", Vector3.new(4.5,.18,.3), CFrame.new(.8,-.35,1.55), "Mechanical"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(8,1.2,4)), Aerodynamics={Kind="Wing",Area=22,LiftCoefficient=1.05,DragCoefficient=.08,StallAngle=22}}))

add(H.part("SweptWing", "Swept Wing", "SWEPT", "Fast swept-back wing with a sharp root and narrow trailing edge.", Vector3.new(8,1.1,6), 34, 210, {
	H.wedge("Panel", Vector3.new(7.7,.55,5.7), CFrame.Angles(0,math.rad(28),0), "Primary"), H.block("RootSpar", Vector3.new(4.3,.35,.5), CFrame.new(-1.3,.15,-.5)*CFrame.Angles(0,math.rad(28),0), "Secondary"), H.wedge("TipCap", Vector3.new(1.4,.45,2.4), CFrame.new(3.2,0,1.15)*CFrame.Angles(0,math.rad(-62),0), "Accent"),
}, {Category="Aerodynamics", Rarity="Uncommon", Stackable=false, AttachmentNodes=anodes(Vector3.new(8,1.1,6)), Aerodynamics={Kind="Wing",Area=24,LiftCoefficient=.95,DragCoefficient=.065,StallAngle=19}}))

add(H.part("DeltaWing", "Delta Wing", "DELTA", "Triangular delta surface suited to compact high-speed aircraft.", Vector3.new(8,1.2,7), 39, 240, {
	H.wedge("DeltaL", Vector3.new(4,.55,6.8), CFrame.new(-1.85,0,0)*CFrame.Angles(0,math.rad(90),0), "Primary"), H.wedge("DeltaR", Vector3.new(4,.55,6.8), CFrame.new(1.85,0,0)*CFrame.Angles(0,math.rad(-90),0), "Primary"), H.block("Root", Vector3.new(1.3,.4,6.3), CFrame.new(0,.15,.1), "Secondary"), H.block("TrailingStrip", Vector3.new(5.2,.18,.3), CFrame.new(0,-.3,2.95), "Accent"),
}, {Category="Aerodynamics", Rarity="Uncommon", Stackable=false, AttachmentNodes=anodes(Vector3.new(8,1.2,7)), Aerodynamics={Kind="Wing",Area=26,LiftCoefficient=.88,DragCoefficient=.06,StallAngle=26}}))

add(H.part("StubWing", "Stub Wing", "STUB", "Short thick lifting stub for missiles, hovercraft and heavy gunships.", Vector3.new(4.5,1.5,3), 25, 260, {
	H.wedge("Body", Vector3.new(4.3,1.1,2.8), CFrame.Angles(0,math.rad(90),0), "Primary"), H.block("RootPlate", Vector3.new(.7,1.35,2.7), CFrame.new(-1.85,0,0), "Secondary"), H.wedge("Tip", Vector3.new(.9,.75,1.7), CFrame.new(1.75,0,.15)*CFrame.Angles(0,math.rad(-90),0), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(4.5,1.5,3)), Aerodynamics={Kind="Wing",Area=10,LiftCoefficient=.8,DragCoefficient=.09,StallAngle=24}}))

add(H.part("TailFin", "Tail Fin", "TAIL FIN", "Tall fixed stabiliser with a swept leading edge.", Vector3.new(2,5,4), 21, 180, {
	H.wedge("Fin", Vector3.new(1.2,4.7,3.8), CFrame.Angles(0,0,math.rad(-8)), "Primary"), H.block("Base", Vector3.new(1.6,.55,3.5), CFrame.new(0,-2.05,0), "Secondary"), H.block("Cap", Vector3.new(1,.3,1.8), CFrame.new(0,2.05,.65), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(2,5,4)), Aerodynamics={Kind="Stabilizer",Area=9,Axis="Yaw",DragCoefficient=.035}}))

add(H.part("Rudder", "Rudder", "RUDDER", "Articulated vertical control surface for yaw authority.", Vector3.new(1.5,4.5,3.2), 18, 150, {
	H.wedge("Surface", Vector3.new(1,4.1,3), nil, "Primary"), H.cylinder("Hinge", Vector3.new(.4,.5,.5), CFrame.new(0,0,-1.35)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.block("Trim", Vector3.new(1.1,.3,2.2), CFrame.new(0,-1.55,.25), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(1.5,4.5,3.2)), Aerodynamics={Kind="ControlSurface",Axis="Yaw",Area=7,Authority=1.0,DragCoefficient=.04}, Controls={"Yaw"}}))

add(H.part("Elevator", "Elevator", "ELEVATOR", "Horizontal tail control surface providing pitch authority.", Vector3.new(5,1.2,2.8), 19, 150, {
	H.wedge("Surface", Vector3.new(4.7,.75,2.6), CFrame.Angles(0,math.rad(90),0), "Primary"), H.cylinder("Hinge", Vector3.new(4.4,.35,.35), CFrame.new(0,0,-1.15)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.block("Counterweight", Vector3.new(1.2,.35,.6), CFrame.new(0,.35,.85), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(5,1.2,2.8)), Aerodynamics={Kind="ControlSurface",Axis="Pitch",Area=8,Authority=1.0,DragCoefficient=.04}, Controls={"Pitch"}}))

add(H.part("Aileron", "Aileron", "AILERON", "Long narrow roll-control surface intended for wing trailing edges.", Vector3.new(5.5,.9,1.6), 13, 120, {
	H.wedge("Surface", Vector3.new(5.2,.55,1.4), CFrame.Angles(0,math.rad(90),0), "Primary"), H.cylinder("Hinge", Vector3.new(5,.25,.25), CFrame.new(0,0,-.6)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.block("Servo", Vector3.new(.7,.5,.7), CFrame.new(-1.6,.25,.15), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(5.5,.9,1.6)), Aerodynamics={Kind="ControlSurface",Axis="Roll",Area=5.5,Authority=.9,DragCoefficient=.035}, Controls={"Roll"}}))

add(H.part("Airbrake", "Airbrake", "AIRBRAKE", "Deployable drag panel with twin actuators for aggressive deceleration.", Vector3.new(4,1.3,4), 22, 170, {
	H.block("Panel", Vector3.new(3.7,.45,3.7), CFrame.new(0,.25,0), "Primary", Enum.Material.DiamondPlate, "ControlSurface"), H.cylinder("Hinge", Vector3.new(3.2,.35,.35), CFrame.new(0,-.1,1.55)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.block("ActuatorL", Vector3.new(.35,.8,.35), CFrame.new(-1.1,-.25,.5)*CFrame.Angles(math.rad(25),0,0), "Accent"), H.block("ActuatorR", Vector3.new(.35,.8,.35), CFrame.new(1.1,-.25,.5)*CFrame.Angles(math.rad(25),0,0), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(4,1.3,4)), Aerodynamics={Kind="Airbrake",Area=12,DragCoefficient=1.1,Authority=1.0}, Controls={"Brake"}}))

add(H.part("Spoiler", "Spoiler", "SPOILER", "Raised rear aerofoil that trades speed for stability and downforce.", Vector3.new(6,2.5,2), 20, 160, {
	H.block("Blade", Vector3.new(5.7,.45,1.4), CFrame.new(0,.8,0)*CFrame.Angles(math.rad(-12),0,0), "Primary"), H.block("PostL", Vector3.new(.35,1.8,.45), CFrame.new(-1.9,-.2,0), "Secondary"), H.block("PostR", Vector3.new(.35,1.8,.45), CFrame.new(1.9,-.2,0), "Secondary"), H.wedge("EndL", Vector3.new(.45,1.2,1.7), CFrame.new(-2.75,.75,0), "Accent"), H.wedge("EndR", Vector3.new(.45,1.2,1.7), CFrame.new(2.75,.75,0)*CFrame.Angles(0,math.pi,0), "Accent"),
}, {Category="Aerodynamics", AttachmentNodes=anodes(Vector3.new(6,2.5,2)), Aerodynamics={Kind="Spoiler",Area=7,DownforceCoefficient=.55,DragCoefficient=.12}}))

return parts
