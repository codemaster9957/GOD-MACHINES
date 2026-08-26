--!strict
-- Pure, deterministic rules shared by the quick-swap server and client surfaces.

local QuickSwapRules = {}

QuickSwapRules.MaxSlots = 3
QuickSwapRules.MaxBlueprintNameLength = 40
QuickSwapRules.CooldownSeconds = 8

local function cleanName(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local name = value:match("^%s*(.-)%s*$") or ""
	name = name:gsub("[%c]", "")
	if name == "" then
		return nil
	end
	if #name > QuickSwapRules.MaxBlueprintNameLength then
		return nil
	end
	return name
end

function QuickSwapRules.NormalizeSlots(raw: any): {[number]: string}
	local slots: {[number]: string} = {}
	if type(raw) ~= "table" then
		return slots
	end
	for slot = 1, QuickSwapRules.MaxSlots do
		local name = cleanName(raw[slot])
		if name then
			slots[slot] = name
		end
	end
	return slots
end

function QuickSwapRules.AssignSlot(raw: any, slot: any, blueprintName: any): (boolean, any)
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > QuickSwapRules.MaxSlots then
		return false, "InvalidQuickSwapSlot"
	end
	local slots = QuickSwapRules.NormalizeSlots(raw)
	if blueprintName == nil or (type(blueprintName) == "string" and blueprintName:match("^%s*$") ~= nil) then
		slots[slot] = nil
		return true, slots
	end
	local name = cleanName(blueprintName)
	if not name then
		return false, "InvalidBlueprintName"
	end
	slots[slot] = name
	return true, slots
end

function QuickSwapRules.NextAssignedSlot(raw: any, currentSlot: any): (number?, string?)
	local slots = QuickSwapRules.NormalizeSlots(raw)
	local current = if type(currentSlot) == "number" and currentSlot % 1 == 0 then currentSlot else 0
	if current < 0 or current > QuickSwapRules.MaxSlots then
		current = 0
	end
	for offset = 1, QuickSwapRules.MaxSlots do
		local slot = ((current + offset - 1) % QuickSwapRules.MaxSlots) + 1
		local name = slots[slot]
		if name then
			return slot, name
		end
	end
	return nil, nil
end

function QuickSwapRules.CooldownRemaining(lastSwapAt: any, now: any, duration: any): number
	if type(lastSwapAt) ~= "number" then
		return 0
	end
	local current = if type(now) == "number" then now else 0
	local window = if type(duration) == "number" then math.max(0, duration) else QuickSwapRules.CooldownSeconds
	return math.max(0, window - math.max(0, current - lastSwapAt))
end

return QuickSwapRules
