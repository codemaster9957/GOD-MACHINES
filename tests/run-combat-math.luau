--!strict

local roblox = require("@lune/roblox")

Vector3 = roblox.Vector3
CFrame = roblox.CFrame
Random = roblox.Random

local run = require("./CombatMathTests")
local CombatMath = require("../src/ReplicatedStorage/MechFramework/Shared/CombatMath")

run(CombatMath)
print("CombatMathTests: PASS")
