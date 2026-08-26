--!strict
-- Pure policy for deriving safe, deterministic weapon action groups.

local Policy = {}

local VALID_ACTIONS: {[string]: boolean} = {
	Primary = true,
	Secondary = true,
}

export type Groups = {
	Primary: {string},
	Secondary: {string},
}

function Policy.Derive(components: {[string]: any}?): Groups
	local groups: Groups = {
		Primary = {},
		Secondary = {},
	}

	if type(components) ~= "table" then
		return groups
	end

	local ids: {string} = {}
	for componentId, component in pairs(components) do
		if
			type(componentId) == "string"
			and type(component) == "table"
			and component.Destroyed ~= true
			and type(component.Combat) == "table"
		then
			table.insert(ids, componentId)
		end
	end
	table.sort(ids)

	for _, componentId in ipairs(ids) do
		local component = components[componentId]
		local requested = component.Combat.DefaultAction
		if requested == "Secondary" then
			table.insert(groups.Secondary, componentId)
		else
			table.insert(groups.Primary, componentId)
		end
	end

	return groups
end

function Policy.IsValidAction(action: any): boolean
	return type(action) == "string" and VALID_ACTIONS[action] == true
end

return table.freeze(Policy)
