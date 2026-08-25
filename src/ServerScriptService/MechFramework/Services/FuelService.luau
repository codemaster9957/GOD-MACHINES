--!strict
-- Canonical machine fuel ledger. Tanks are component state; engines/generators consume atomically from matching stores.
-- Read-only queries never mutate fuel, while all consumption is server-authoritative.

local Fuel: any = { _mechs=nil }

local function number(value: any, fallback: number): number
	local parsed=tonumber(value)
	return if parsed~=nil and parsed==parsed and parsed~=math.huge and parsed~=-math.huge then parsed else fallback
end

local function normalizeType(value: any): string
	local name=tostring(value or "Liquid")
	return if name~="" then name else "Liquid"
end

function Fuel:Init(container: any)
	self._mechs=container:Get("MechService")
end

function Fuel:_stores(mechId: string, fuelType: string?): ({any}, number, number)
	local mech=self._mechs:Get(mechId)
	if not mech then return {},0,0 end
	local wanted=if fuelType then normalizeType(fuelType) else nil
	local stores={}
	local amount,capacity=0,0
	for componentId,component in pairs(mech.Components) do
		if component.Destroyed or not component.Fuel then continue end
		local config=component.Fuel
		local storeCapacity=math.max(0,number(config.Capacity,0))
		if storeCapacity<=0 then continue end
		local kind=normalizeType(config.Type)
		if wanted and kind~=wanted then continue end
		config.Amount=math.clamp(number(config.Amount,storeCapacity),0,storeCapacity)
		amount+=config.Amount
		capacity+=storeCapacity
		table.insert(stores,{Id=componentId,Config=config,Type=kind,Amount=config.Amount,Capacity=storeCapacity})
	end
	return stores,amount,capacity
end

function Fuel:GetState(mechId: string, fuelType: string?): any
	local stores,amount,capacity=self:_stores(mechId,fuelType)
	return {Type=fuelType and normalizeType(fuelType) or "All",Amount=amount,Capacity=capacity,Stores=stores,Fraction=if capacity>0 then amount/capacity else 0}
end

function Fuel:GetAvailable(mechId: string, fuelType: string?): number
	local _,amount=self:_stores(mechId,fuelType)
	return amount
end

function Fuel:CanConsume(mechId: string, fuelType: string?, amount: number): boolean
	if amount<0 or amount~=amount or amount==math.huge then return false end
	return self:GetAvailable(mechId,fuelType)+1e-6>=amount
end

function Fuel:Consume(mechId: string, fuelType: string?, amount: number, allowPartial: boolean?): (number,string)
	if amount<=0 or amount~=amount or amount==math.huge then return 0,"InvalidAmount" end
	local stores,available=self:_stores(mechId,fuelType)
	if available<=0 then return 0,"NoFuel" end
	if available+1e-6<amount and allowPartial~=true then return 0,"InsufficientFuel" end
	local supplied=math.min(amount,available)
	local remaining=supplied
	-- Deterministic drain order keeps simulation reproducible when multiple tanks exist.
	table.sort(stores,function(a,b) return tostring(a.Id)<tostring(b.Id) end)
	for _,store in ipairs(stores) do
		if remaining<=1e-6 then break end
		local current=math.clamp(number(store.Config.Amount,store.Capacity),0,store.Capacity)
		local used=math.min(current,remaining)
		store.Config.Amount=current-used
		remaining-=used
	end
	return supplied,if supplied+1e-6>=amount then "Consumed" else "Partial"
end

function Fuel:Refill(mechId: string, fuelType: string?, amount: number): (number,string)
	if amount<=0 or amount~=amount or amount==math.huge then return 0,"InvalidAmount" end
	local stores=self:_stores(mechId,fuelType)
	if #stores==0 then return 0,"NoFuelStorage" end
	local remaining=amount
	local filled=0
	table.sort(stores,function(a,b) return tostring(a.Id)<tostring(b.Id) end)
	for _,store in ipairs(stores) do
		if remaining<=1e-6 then break end
		local current=math.clamp(number(store.Config.Amount,store.Capacity),0,store.Capacity)
		local room=store.Capacity-current
		local added=math.min(room,remaining)
		store.Config.Amount=current+added
		remaining-=added; filled+=added
	end
	return filled,if filled>0 then "Refilled" else "Full"
end

return Fuel
