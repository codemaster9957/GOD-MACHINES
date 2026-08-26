from pathlib import Path

CHECKS = {
    "src/ReplicatedStorage/MechFramework/Shared/CombatMath.luau": [
        "function CombatMath.ClampDirection",
        "function CombatMath.SpreadDirection",
        "function CombatMath.InterceptDirection",
        "function CombatMath.Falloff",
    ],
    "src/ReplicatedStorage/MechFramework/Shared/WeaponDefinitions.luau": [
        "MaxBloom =",
        "BloomPerShot =",
        "YawArc =",
        "PitchArc =",
        "TraverseSpeed =",
    ],
    "src/ServerScriptService/MechFramework/Services/CombatService.luau": [
        "CombatMath.ClampDirection(",
        "CombatMath.InterceptDirection(",
        "ShotSeed=",
        "_bloomFor",
        "TargetMechId",
        "TargetComponentId",
    ],
    "src/ServerScriptService/MechFramework/Services/ProjectileService.luau": [
        "CombatMath.SpreadDirection(",
        "CombatMath.Falloff(",
        "ShotSeed",
    ],
    "src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau": [
        "TargetMechId",
        "TargetComponentId",
        "AIM_REFRESH_RATE",
        "RunService.RenderStepped",
    ],
}

for filename, needles in CHECKS.items():
    text = Path(filename).read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"COMBAT POLISH CONTRACT FAILED: {filename} missing {needle!r}")

print("COMBAT POLISH CONTRACT PASSED")
