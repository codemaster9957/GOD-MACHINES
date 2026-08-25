--!strict
-- Two-phase lifecycle prevents require-order coupling between services.
local Container = {}
Container.__index = Container

function Container.new()
	return setmetatable({ _services = {}, _order = {}, _initialized = false, _started = false }, Container)
end

function Container:Register(name: string, service: any)
	assert(not self._services[name], `Duplicate service: {name}`)
	self._services[name] = service
	table.insert(self._order, name)
end

function Container:Get(name: string): any
	local service = self._services[name]
	assert(service, `Unknown service: {name}`)
	return service
end

function Container:Has(name: string): boolean
	return self._services[name] ~= nil
end

function Container:Init()
	assert(not self._initialized, "Container already initialized")
	self._initialized = true
	for _, name in self._order do
		local service = self._services[name]
		print("[MechFramework] Init", name)
		if service.Init then
			service:Init(self)
		end
	end
	print("[MechFramework] container:Init() complete")
end

function Container:Start()
	assert(self._initialized and not self._started, "Invalid container lifecycle")
	self._started = true
	for _, name in self._order do
		local service = self._services[name]
		print("[MechFramework] Start", name)
		if service.Start then
			service:Start()
		end
	end
	print("[MechFramework] container:Start() complete")
end

return Container