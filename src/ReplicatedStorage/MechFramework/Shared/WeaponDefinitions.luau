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
	Category = "Experimental", Mode = "Hitscan", Damage = 10, DamageType = "Kinetic", FireRate = 1,
	ProjectileSpeed = 500, Spread = 0, MaxBloom = 4, BloomPerShot = 0.15, BloomRecovery = 5,
	Recoil = 0, EnergyUsage = 0, HeatGenerated = 0, AmmoType = "None", AmmoUsage = 0,
	MagazineSize = 30, ReserveAmmo = 120, ReloadTime = 2, ReloadBehaviour = "Magazine",
	ExplosionRadius = 0, Penetration = 0, Range = 1000, TurnSpeed = nil, TraverseSpeed = 90,
	YawArc = 180, PitchArc = 90, FireTolerance = 4, RequiredPower = 0, Pellets = 1,
	LockRange = 0, LockAngle = 0, SeekerStrength = 0, VisualProfile = "Ballistic",
})

Definitions.Presets = table.freeze({
	MachineGun = { Category="MachineGun", Mode="Hitscan", Damage=8, FireRate=10, Spread=1.5, MaxBloom=5, BloomPerShot=.22, Recoil=90, AmmoType="Light", AmmoUsage=1, MagazineSize=60, ReserveAmmo=240, ReloadTime=2.4, Range=900 },
	Cannon = { Category="Cannon", Mode="Projectile", Damage=150, DamageType="Explosive", FireRate=.25, ProjectileSpeed=420, Recoil=9000, AmmoType="Shell", AmmoUsage=1, MagazineSize=4, ReserveAmmo=20, ReloadTime=3.2, ExplosionRadius=12, Penetration=40, Range=1800, VisualProfile="HeavyBallistic" },
	Autocannon = { Category="Autocannon", Mode="Projectile", Damage=24, FireRate=5, ProjectileSpeed=800, Spread=.4, MaxBloom=3, Recoil=650, AmmoType="Autocannon", AmmoUsage=1, MagazineSize=30, ReserveAmmo=150, ReloadTime=2.8, Penetration=8, Range=1500 },
	Shotgun = { Category="Shotgun", Mode="Hitscan", Damage=12, FireRate=1.2, Pellets=10, Spread=7, MaxBloom=9, BloomPerShot=1, Recoil=1200, AmmoType="Shell", AmmoUsage=1, MagazineSize=8, ReserveAmmo=40, ReloadTime=2.7, Range=350 },
	Railgun = { Category="Railgun", Mode="Hitscan", Damage=300, DamageType="Energy", FireRate=.12, Recoil=14000, EnergyUsage=220, HeatGenerated=90, Penetration=160, Range=5000, RequiredPower=180, MagazineSize=1, ReserveAmmo=8, ReloadTime=4, VisualProfile="Railgun" },
	Laser = { Category="Laser", Mode="Hitscan", Damage=35, DamageType="Energy", FireRate=4, EnergyUsage=18, HeatGenerated=14, AmmoUsage=0, ReloadBehaviour="None", Range=2200, RequiredPower=15, VisualProfile="Laser" },
	Plasma = { Category="Plasma", Mode="Projectile", Damage=85, DamageType="Energy", FireRate=.8, ProjectileSpeed=300, EnergyUsage=50, HeatGenerated=40, AmmoUsage=0, ReloadBehaviour="None", ExplosionRadius=7, Range=1100, RequiredPower=45, VisualProfile="Plasma" },
	Missile = { Category="Missile", Mode="Guided", Damage=120, DamageType="Explosive", FireRate=.4, ProjectileSpeed=240, AmmoType="Missile", AmmoUsage=1, MagazineSize=4, ReserveAmmo=16, ReloadTime=3.5, ExplosionRadius=18, Range=3000, LockRange=2500, LockAngle=35, SeekerStrength=75, VisualProfile="Missile" },
	Rocket = { Category="Rocket", Mode="Projectile", Damage=90, DamageType="Explosive", FireRate=.8, ProjectileSpeed=210, AmmoType="Rocket", AmmoUsage=1, MagazineSize=6, ReserveAmmo=30, ReloadTime=3, ExplosionRadius=14, Range=1600, VisualProfile="Rocket" },
	Flamethrower = { Category="Flamethrower", Mode="Stream", Damage=9, DamageType="Heat", FireRate=12, ProjectileSpeed=120, EnergyUsage=2, HeatGenerated=5, AmmoUsage=0, ReloadBehaviour="None", Range=120, VisualProfile="Flame" },
	MeleeBlade = { Category="MeleeBlade", Mode="Melee", Damage=100, DamageType="Melee", FireRate=.8, Recoil=0, AmmoUsage=0, ReloadBehaviour="None", Range=14, TraverseSpeed=0, VisualProfile="Melee" },
	Drill = { Category="Drill", Mode="Melee", Damage=20, DamageType="Melee", FireRate=8, EnergyUsage=8, HeatGenerated=6, AmmoUsage=0, ReloadBehaviour="None", Range=10, TraverseSpeed=0, VisualProfile="Melee" },
	Saw = { Category="Saw", Mode="Melee", Damage=28, DamageType="Melee", FireRate=6, EnergyUsage=10, HeatGenerated=8, AmmoUsage=0, ReloadBehaviour="None", Range=12, TraverseSpeed=0, VisualProfile="Melee" },
	Experimental = { Category="Experimental", Mode="Projectile", Damage=1, FireRate=1, Range=1000 },
})

local function copy(v: any): any local o = {}; for k, x in v do o[k] = type(x)=="table" and copy(x) or x end; return o end
function Definitions.Resolve(config: {[string]: any}?): {[string]: any}
	config = config or {}; local preset = Definitions.Presets[config.Preset or config.Category] or {}
	local result = copy(Definitions.Defaults); for k,v in preset do result[k]=v end; for k,v in config do result[k]=v end
	if config.TraverseSpeed == nil and config.TurnSpeed ~= nil then result.TraverseSpeed = config.TurnSpeed end
	return result
end
return Definitions
