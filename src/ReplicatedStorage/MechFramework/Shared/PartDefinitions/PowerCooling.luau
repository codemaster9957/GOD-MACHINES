--!strict
local H = require(script.Parent.Parent:WaitForChild("PartDefinitionHelpers"))
local parts = {}
local function add(def) table.insert(parts, def) end
local function unodes(size) return H.boxNodes(size, "Utility", {"Structural","Utility"}) end

add(H.part("SmallReactor", "Small Reactor", "REACTOR", "Compact reactor vessel with glowing core bands and radiator fins.", Vector3.new(3.5,3.5,3.5), 80, 180, {
	H.cylinder("Core", Vector3.new(2.6,2.7,2.7), CFrame.Angles(0,0,math.rad(90)), "Primary"), H.cylinder("CoreGlow", Vector3.new(2.8,1.4,1.4), CFrame.Angles(0,0,math.rad(90)), "Accent", Enum.Material.Neon), H.block("FinTop", Vector3.new(2.8,.25,2.8), CFrame.new(0,1.45,0), "Secondary"), H.block("FinBottom", Vector3.new(2.8,.25,2.8), CFrame.new(0,-1.45,0), "Secondary"), H.block("Console", Vector3.new(1.3,.65,.35), CFrame.new(0,.45,-1.55), "Mechanical"),
}, {Category="PowerCooling", Rarity="Uncommon", Stackable=false, AttachmentNodes=unodes(Vector3.new(3.5,3.5,3.5)), Power={Generation=100,MaximumOutput=100,Demand=0}, Heat={Generation=8,Capacity=200}}))

add(H.part("FusionReactor", "Fusion Reactor", "FUSION", "Large ringed fusion core with magnetic coils and extreme output.", Vector3.new(6,6,6), 210, 420, {
	H.ball("Core", Vector3.new(2.6,2.6,2.6), nil, "Accent", Enum.Material.Neon), H.cylinder("RingX", Vector3.new(.45,4.8,4.8), nil, "Primary"), H.cylinder("RingY", Vector3.new(.45,4.8,4.8), CFrame.Angles(0,0,math.rad(90)), "Primary"), H.cylinder("RingZ", Vector3.new(.45,4.8,4.8), CFrame.Angles(0,math.rad(90),0), "Primary"), H.block("Base", Vector3.new(4.6,.7,4.6), CFrame.new(0,-2.55,0), "Secondary"), H.block("Bus", Vector3.new(3.2,.35,.7), CFrame.new(0,2.15,0), "Mechanical"),
}, {Category="PowerCooling", Rarity="Rare", Stackable=false, AttachmentNodes=unodes(Vector3.new(6,6,6)), Power={Generation=520,MaximumOutput=600,Demand=0}, Heat={Generation=55,Capacity=480}}))

add(H.part("MicroGenerator", "Micro Generator", "GENERATOR", "Small fuel generator with exposed alternator, intake and exhaust.", Vector3.new(3,3,4), 44, 220, {
	H.block("Engine", Vector3.new(2.4,1.8,2.1), CFrame.new(0,-.35,-.65), "Primary"), H.cylinder("Alternator", Vector3.new(1.4,2.1,2.1), CFrame.new(0,.25,.95)*CFrame.Angles(0,math.rad(90),0), "Secondary"), H.cylinder("Rotor", Vector3.new(1.6,.6,.6), CFrame.new(0,.25,1.1)*CFrame.Angles(0,math.rad(90),0), "Accent", Enum.Material.Neon, "EngineSpinner"), H.cylinder("Exhaust", Vector3.new(1.6,.35,.35), CFrame.new(.8,1.05,-1.1)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="PowerCooling", Stackable=false, AttachmentNodes=unodes(Vector3.new(3,3,4)), Power={Generation=45,MaximumOutput=45,Demand=0}, Fuel={Type="Liquid",Use=1.2}, Heat={Generation=11,Capacity=90}}))

add(H.part("BatteryPack", "Battery Pack", "BATTERY", "Stack of protected energy cells with illuminated charge bars.", Vector3.new(4,2.5,4), 52, 260, {
	H.block("Case", Vector3.new(3.8,2.2,3.8), nil, "Secondary"), H.block("Cell1", Vector3.new(.75,1.6,3.2), CFrame.new(-1.2,0,-.1), "Primary"), H.block("Cell2", Vector3.new(.75,1.6,3.2), CFrame.new(-.4,0,-.1), "Primary"), H.block("Cell3", Vector3.new(.75,1.6,3.2), CFrame.new(.4,0,-.1), "Primary"), H.block("Cell4", Vector3.new(.75,1.6,3.2), CFrame.new(1.2,0,-.1), "Primary"), H.block("ChargeBar", Vector3.new(2.6,.22,.25), CFrame.new(0,.7,-1.95), "Accent", Enum.Material.Neon),
}, {Category="PowerCooling", Stackable=false, AttachmentNodes=unodes(Vector3.new(4,2.5,4)), Power={Generation=0,Demand=0,StorageCapacity=260,Capacity=260,Charge=260,StorageOutput=90,StorageInput=70}}))

add(H.part("HeavyBattery", "Heavy Battery", "HEAVY BAT", "Armoured high-capacity battery bank for combat machines and electric drivetrains.", Vector3.new(5,4,5), 125, 430, {
	H.block("ArmourCase", Vector3.new(4.8,3.8,4.8), nil, "Primary"), H.block("Inset", Vector3.new(3.9,2.8,4.85), CFrame.new(0,0,-.05), "Secondary"), H.block("BusL", Vector3.new(.45,.45,3.2), CFrame.new(-1.65,1.65,0), "Accent", Enum.Material.Neon), H.block("BusR", Vector3.new(.45,.45,3.2), CFrame.new(1.65,1.65,0), "Accent", Enum.Material.Neon), H.block("Vent", Vector3.new(2.4,.35,.25), CFrame.new(0,-1.5,-2.4), "Mechanical"),
}, {Category="PowerCooling", Rarity="Uncommon", Stackable=false, AttachmentNodes=unodes(Vector3.new(5,4,5)), Power={Generation=0,Demand=0,StorageCapacity=900,Capacity=900,Charge=900,StorageOutput=260,StorageInput=180}}))

add(H.part("CapacitorBank", "Capacitor Bank", "CAP BANK", "Fast-discharge capacitor cylinders for weapons and burst-demand systems.", Vector3.new(4,4,3), 47, 210, {
	H.cylinder("Cap1", Vector3.new(2.4,1.15,1.15), CFrame.new(-1.1,.75,0)*CFrame.Angles(0,0,math.rad(90)), "Primary"), H.cylinder("Cap2", Vector3.new(2.4,1.15,1.15), CFrame.new(1.1,.75,0)*CFrame.Angles(0,0,math.rad(90)), "Primary"), H.cylinder("Cap3", Vector3.new(2.4,1.15,1.15), CFrame.new(-1.1,-.75,0)*CFrame.Angles(0,0,math.rad(90)), "Primary"), H.cylinder("Cap4", Vector3.new(2.4,1.15,1.15), CFrame.new(1.1,-.75,0)*CFrame.Angles(0,0,math.rad(90)), "Primary"), H.block("Bus", Vector3.new(3.4,.3,.45), CFrame.new(0,1.7,0), "Accent", Enum.Material.Neon), H.block("Backplate", Vector3.new(3.8,3.8,.4), CFrame.new(0,0,1.2), "Secondary"),
}, {Category="PowerCooling", Rarity="Uncommon", Stackable=false, AttachmentNodes=unodes(Vector3.new(4,4,3)), Power={Generation=0,Demand=0,StorageCapacity=180,Capacity=180,Charge=180,StorageOutput=420,StorageInput=220}}))

add(H.part("Radiator", "Radiator", "RADIATOR", "Wide finned radiator that sheds heat but adds vulnerable surface area.", Vector3.new(5,4,1.8), 24, 170, {
	H.block("Frame", Vector3.new(4.8,3.8,.45), nil, "Secondary"), H.block("Fin1", Vector3.new(.25,3.2,1.2), CFrame.new(-1.8,0,0), "Primary"), H.block("Fin2", Vector3.new(.25,3.2,1.2), CFrame.new(-1.2,0,0), "Primary"), H.block("Fin3", Vector3.new(.25,3.2,1.2), CFrame.new(-.6,0,0), "Primary"), H.block("Fin4", Vector3.new(.25,3.2,1.2), nil, "Primary"), H.block("Fin5", Vector3.new(.25,3.2,1.2), CFrame.new(.6,0,0), "Primary"), H.block("Fin6", Vector3.new(.25,3.2,1.2), CFrame.new(1.2,0,0), "Primary"), H.block("Fin7", Vector3.new(.25,3.2,1.2), CFrame.new(1.8,0,0), "Primary"), H.cylinder("Manifold", Vector3.new(4.4,.35,.35), CFrame.new(0,1.55,0)*CFrame.Angles(0,0,math.rad(90)), "Accent"),
}, {Category="PowerCooling", AttachmentNodes=unodes(Vector3.new(5,4,1.8)), Heat={Generation=0,Capacity=50,Dissipation=34}}))

add(H.part("HeatSink", "Heat Sink", "HEATSINK", "Dense radial heat sink for compact high-heat weapon and power builds.", Vector3.new(3.5,3.5,3.5), 29, 190, {
	H.cylinder("Core", Vector3.new(2.7,1.1,1.1), CFrame.Angles(0,math.rad(90),0), "Secondary"), H.block("FinTop", Vector3.new(2.8,.22,1.1), CFrame.new(0,1.2,0), "Primary"), H.block("FinBottom", Vector3.new(2.8,.22,1.1), CFrame.new(0,-1.2,0), "Primary"), H.block("FinLeft", Vector3.new(.22,2.8,1.1), CFrame.new(-1.2,0,0), "Primary"), H.block("FinRight", Vector3.new(.22,2.8,1.1), CFrame.new(1.2,0,0), "Primary"), H.block("FinDiag1", Vector3.new(.22,2.8,1.1), CFrame.Angles(0,0,math.rad(45)), "Accent"), H.block("FinDiag2", Vector3.new(.22,2.8,1.1), CFrame.Angles(0,0,math.rad(-45)), "Accent"),
}, {Category="PowerCooling", AttachmentNodes=unodes(Vector3.new(3.5,3.5,3.5)), Heat={Generation=0,Capacity=85,Dissipation=22}}))

add(H.part("CoolantPump", "Coolant Pump", "PUMP", "Electric circulation pump with twin pipe couplings and exposed impeller housing.", Vector3.new(3,3,4), 33, 190, {
	H.cylinder("PumpBody", Vector3.new(1.5,2.5,2.5), CFrame.new(0,0,-.6)*CFrame.Angles(0,math.rad(90),0), "Primary"), H.cylinder("Impeller", Vector3.new(.45,1.4,1.4), CFrame.new(0,0,-1.4)*CFrame.Angles(0,math.rad(90),0), "Accent", Enum.Material.Neon, "EngineSpinner"), H.block("Motor", Vector3.new(2.1,1.7,1.8), CFrame.new(0,0,1), "Secondary"), H.cylinder("PipeL", Vector3.new(1.2,.55,.55), CFrame.new(-1.25,.7,-.4)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.cylinder("PipeR", Vector3.new(1.2,.55,.55), CFrame.new(1.25,.7,-.4)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="PowerCooling", Stackable=false, AttachmentNodes=unodes(Vector3.new(3,3,4)), Power={Generation=0,Demand=8,Priority=60}, Heat={Generation=2,Capacity=30,Dissipation=14}}))

add(H.part("PowerDistributor", "Power Distributor", "DISTRIBUTOR", "Armoured bus box with six high-current outputs for organising large electrical machines.", Vector3.new(4,3,4), 39, 250, {
	H.block("Box", Vector3.new(3.7,2.7,3.7), nil, "Primary"), H.block("FrontInset", Vector3.new(2.8,1.8,.3), CFrame.new(0,0,-1.9), "Secondary"), H.block("BusA", Vector3.new(2.2,.22,.22), CFrame.new(0,.55,-2.05), "Accent", Enum.Material.Neon), H.block("BusB", Vector3.new(2.2,.22,.22), CFrame.new(0,0,-2.05), "Accent", Enum.Material.Neon), H.block("BusC", Vector3.new(2.2,.22,.22), CFrame.new(0,-.55,-2.05), "Accent", Enum.Material.Neon), H.cylinder("TerminalL", Vector3.new(.5,.45,.45), CFrame.new(-1.65,0,0)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"), H.cylinder("TerminalR", Vector3.new(.5,.45,.45), CFrame.new(1.65,0,0)*CFrame.Angles(0,0,math.rad(90)), "Mechanical"),
}, {Category="PowerCooling", AttachmentNodes=unodes(Vector3.new(4,3,4)), Power={Generation=0,Demand=0,MaximumOutput=0}, Utility={Kind="PowerBus"}}))

return parts
