--!strict
-- Shared tuning contains engineering costs, never arbitrary build-count caps.
local Config = {
	SchemaVersion = 2,
	Debug = true,
	Network = { RequestsPerSecond = 12, Burst = 20 },
	Simulation = { ActiveHz = 30, NearbyHz = 10, DistantHz = 2, SleepAfterSeconds = 8 },
	SaveKey = "MechFramework_v2",
}
return table.freeze(Config)