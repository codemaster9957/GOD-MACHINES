--!strict
-- Data-driven battle modes. New modes compose rules rather than replacing the match service.
local Definitions: any = {}

Definitions.States = {Preparing = true, Spawning = true, Active = true, Ending = true, Results = true}
Definitions.Modes = {
	Duel = {Kind = "PvP", Teams = 2, TeamSize = 1, Objective = "Elimination", TimeLimit = 300, Reward = {Credits = 120, SalvageRolls = 1}},
	Skirmish2v2 = {Kind = "PvP", Teams = 2, TeamSize = 2, Objective = "Elimination", TimeLimit = 420, Reward = {Credits = 180, SalvageRolls = 1}},
	TeamBattle = {Kind = "PvP", Teams = 2, TeamSize = 8, Objective = "Elimination", TimeLimit = 600, Reward = {Credits = 220, SalvageRolls = 2}},
	FreeForAll = {Kind = "PvP", Teams = 0, TeamSize = 1, Objective = "LastMechStanding", TimeLimit = 480, Reward = {Credits = 180, SalvageRolls = 1}},
	LargeMechWar = {Kind = "PvP", Teams = 2, TeamSize = 32, Objective = "Score", TimeLimit = 1200, Reward = {Credits = 400, SalvageRolls = 3}},
	PvEMission = {Kind = "PvE", Teams = 1, TeamSize = 4, Objective = "EliminateHostiles", TimeLimit = 600, EnemyCount = 3, Reward = {Credits = 180, LootTable = "MissionStandard"}},
	BossFight = {Kind = "PvE", Teams = 1, TeamSize = 8, Objective = "DestroyBoss", TimeLimit = 900, EnemyCount = 1, Reward = {Credits = 500, LootTable = "BossPrototype"}},
	Survival = {Kind = "PvE", Teams = 1, TeamSize = 8, Objective = "SurviveWaves", TimeLimit = 900, Reward = {Credits = 300, LootTable = "MissionStandard"}},
	ConvoyDefence = {Kind = "PvE", Teams = 1, TeamSize = 8, Objective = "Escort", TimeLimit = 900, Reward = {Credits = 320, LootTable = "MissionStandard"}},
	BaseAssault = {Kind = "Hybrid", Teams = 2, TeamSize = 12, Objective = "DestroyObjectives", TimeLimit = 900, Reward = {Credits = 350, SalvageRolls = 2}},
	SalvageExpedition = {Kind = "PvE", Teams = 1, TeamSize = 6, Objective = "ExtractSalvage", TimeLimit = 720, Reward = {Credits = 150, LootTable = "SalvageWreck"}},
}

Definitions.Arenas = {
	AdaptiveOpenField = {
		Center = Vector3.new(0, 20, 0), MinRadius = 180, Padding = 40, MaxRadius = 2000,
		Features = {OpenField = true, RoughTerrain = true, Verticality = true},
		Hazards = {}, DestructibleCover = true,
	},
}

function Definitions.ResolveMode(name: string): any?
	local value = Definitions.Modes[name]
	if not value then return nil end
	return table.clone(value)
end

return Definitions