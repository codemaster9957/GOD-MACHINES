--!strict
-- Pure behavior contract for persisted three-slot vehicle quick swap.

local failures = {}

local function expect(condition: boolean, message: string)
	if not condition then
		table.insert(failures, message)
	end
end

local loaded, Rules = pcall(require, "../src/ReplicatedStorage/MechFramework/Shared/QuickSwapRules")
expect(loaded, "QuickSwapRules must be available to server and client")

if loaded then
	local normalized = Rules.NormalizeSlots({
		[1] = "  Scout  ",
		[2] = "",
		[3] = "Tank",
		[4] = "Ignored",
	})
	expect(normalized[1] == "Scout", "slot names must be trimmed")
	expect(normalized[2] == nil, "blank slot names must be removed")
	expect(normalized[3] == "Tank", "valid third slot must survive")
	expect(normalized[4] == nil, "only three slots may exist")

	local ok, assigned = Rules.AssignSlot(normalized, 2, "  Hover Jet ")
	expect(ok == true and assigned[2] == "Hover Jet", "assigning a valid saved vehicle must update a copied slot set")
	expect(normalized[2] == nil, "assigning a slot must not mutate the caller's table")

	local badSlot, badSlotReason = Rules.AssignSlot(normalized, 4, "Tank")
	expect(badSlot == false and badSlotReason == "InvalidQuickSwapSlot", "out-of-range slots must be rejected")

	local badName, badNameReason = Rules.AssignSlot(normalized, 1, string.rep("x", 41))
	expect(badName == false and badNameReason == "InvalidBlueprintName", "oversized blueprint names must be rejected")

	local slot, name = Rules.NextAssignedSlot({[1] = "Scout", [3] = "Tank"}, 1)
	expect(slot == 3 and name == "Tank", "cycling must skip empty slots")
	slot, name = Rules.NextAssignedSlot({[1] = "Scout", [3] = "Tank"}, 3)
	expect(slot == 1 and name == "Scout", "cycling must wrap to the first assigned slot")
	slot, name = Rules.NextAssignedSlot({}, nil)
	expect(slot == nil and name == nil, "cycling an empty loadout must return no target")

	expect(Rules.CooldownRemaining(10, 15, 8) == 3, "cooldown must report exact remaining time")
	expect(Rules.CooldownRemaining(10, 20, 8) == 0, "expired cooldown must clamp to zero")
	expect(Rules.CooldownRemaining(nil, 20, 8) == 0, "a player with no prior swap must be ready")
end

if #failures > 0 then
	error("QUICK SWAP SPEC FAILED:\n  - " .. table.concat(failures, "\n  - "), 0)
end

print("QUICK SWAP SPEC PASSED")
