--!strict
-- Weapon behavior is configuration: new categories do not require new combat code.
local Definitions = {}

Definitions.Categories = table.freeze({
	MachineGun = "Ballistic", Cannon = "Ballistic", Autocannon = "Ballistic", Shotgun = "Ballistic",
	Railgun = "Electromagnetic", Laser = "Energy", Plasma = "Energy", Missile = "Guided",
	Rocket = "Projectile", Flamethrower = "Stream", MeleeBlade = "Melee", Drill = "Melee",
	Saw = "Melee", Experimental = "Experimental",
})

Definitions.Defaults = table.freeze({
	Category = "Experimental", Mode = "Hitscan", Damage = 10, FireRate = 1,
	ProjectileSpeed = 500, Spread = 0, Recoil = 0, EnergyUsage = 0, HeatGenerated = 0,
	AmmoType = "None", AmmoUsage = 0, ReloadBehaviour = "None", ExplosionRadius = 0,
	Penetration = 0, Range = 1000, TurnSpeed = 0, RequiredPower = 0, Pellets = 1,
})

Definitions.Presets = table.freeze({
	MachineGun = { Category="MachineGun", Mode="Hitscan", Damage=8, FireRate=10, Spread=1.5, Recoil=90, AmmoType="Light", AmmoUsage=1, Range=900 },
	Cannon = { Category="Cannon", Mode="Projectile", Damage=150, FireRate=.25, ProjectileSpeed=420, Recoil=9000, AmmoType="Shell", AmmoUsage=1, ExplosionRadius=12, Penetration=40, Range=1800 },
	Autocannon = { Category="Autocannon", Mode="Projectile", Damage=24, FireRate=5, ProjectileSpeed=800, Spread=.4, Recoil=650, AmmoType="Autocannon", AmmoUsage=1, Penetration=8, Range=1500 },
	Shotgun = { Category="Shotgun", Mode="Hitscan", Damage=12, FireRate=1.2, Pellets=10, Spread=7, Recoil=1200, AmmoType="Shell", AmmoUsage=1, Range=350 },
	Railgun = { Category="Railgun", Mode="Hitscan", Damage=300, FireRate=.12, Recoil=14000, EnergyUsage=220, HeatGenerated=90, Penetration=160, Range=5000, RequiredPower=180 },
	Laser = { Category="Laser", Mode="Hitscan", Damage=35, FireRate=4, EnergyUsage=18, HeatGenerated=14, Range=2200, RequiredPower=15 },
	Plasma = { Category="Plasma", Mode="Projectile", Damage=85, FireRate=.8, ProjectileSpeed=300, EnergyUsage=50, HeatGenerated=40, ExplosionRadius=7, Range=1100, RequiredPower=45 },
	Missile = { Category="Missile", Mode="Guided", Damage=120, FireRate=.4, ProjectileSpeed=240, AmmoType="Missile", AmmoUsage=1, ExplosionRadius=18, Range=3000 },
	Rocket = { Category="Rocket", Mode="Projectile", Damage=90, FireRate=.8, ProjectileSpeed=210, AmmoType="Rocket", AmmoUsage=1, ExplosionRadius=14, Range=1600 },
	Flamethrower = { Category="Flamethrower", Mode="Stream", Damage=9, FireRate=12, ProjectileSpeed=120, EnergyUsage=2, HeatGenerated=5, Range=120 },
	MeleeBlade = { Category="MeleeBlade", Mode="Melee", Damage=100, FireRate=.8, Recoil=0, Range=14 },
	Drill = { Category="Drill", Mode="Melee", Damage=20, FireRate=8, EnergyUsage=8, HeatGenerated=6, Range=10 },
	Saw = { Category="Saw", Mode="Melee", Damage=28, FireRate=6, EnergyUsage=10, HeatGenerated=8, Range=12 },
	Experimental = { Category="Experimental", Mode="Projectile", Damage=1, FireRate=1, Range=1000 },
})

local function copy(v: any): any local o = {}; for k, x in v do o[k] = type(x)=="table" and copy(x) or x end; return o end
function Definitions.Resolve(config: {[string]: any}?): {[string]: any}
	config = config or {}; local preset = Definitions.Presets[config.Preset or config.Category] or {}
	local result = copy(Definitions.Defaults); for k,v in preset do result[k]=v end; for k,v in config do result[k]=v end
	return result
end
return Definitions