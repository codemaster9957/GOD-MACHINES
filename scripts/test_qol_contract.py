from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'src/ReplicatedStorage/MechFramework/Shared/QoLDefinitions.luau'
CONTROLLER = ROOT / 'src/StarterPlayer/StarterPlayerScripts/GodMachinesQoL.client.luau'
BUILD_INPUT = ROOT / 'src/StarterPlayer/StarterPlayerScripts/GodMachinesBuilder/BuildInput.luau'
QUICK_SWAP = ROOT / 'src/StarterPlayer/StarterPlayerScripts/VehicleQuickSwap.client.luau'
TRADE = ROOT / 'src/StarterPlayer/StarterPlayerScripts/VehicleTradeController.client.luau'
WEAPON = ROOT / 'src/StarterPlayer/StarterPlayerScripts/WeaponController.client.luau'


def read(path: Path) -> str:
    assert path.exists(), f'missing required QoL file: {path.relative_to(ROOT)}'
    return path.read_text(encoding='utf-8')


def test_manifest_exactly_100_unique_features():
    text = read(MANIFEST)
    ids = re.findall(r'Id\s*=\s*"([a-z0-9_]+)"', text)
    assert len(ids) == 100, f'expected exactly 100 QoL features, found {len(ids)}'
    assert len(set(ids)) == 100, 'QoL feature IDs must be unique'


def test_manifest_category_budget_is_intentional():
    text = read(MANIFEST)
    categories = re.findall(r'Category\s*=\s*"([A-Za-z]+)"', text)
    expected = {
        'Workshop': 25,
        'QuickSwap': 15,
        'Trade': 20,
        'Combat': 15,
        'Accessibility': 20,
        'Reliability': 5,
    }
    actual = {name: categories.count(name) for name in expected}
    assert actual == expected, actual


def test_global_controller_wires_real_qol_surfaces():
    text = read(CONTROLLER)
    for needle in [
        'Enum.KeyCode.K', 'Enum.KeyCode.F10', 'CatalogCardGrid',
        'CaptureFocus()', 'Highlight', 'GodMachinesQoL', 'GMQoL_',
        'commandPalette', 'applyAccessibility', 'showToast',
        'Mouse.Target', 'TargetMechId', 'Crosshair',
    ]:
        assert needle in text, f'missing global QoL behavior: {needle}'


def test_builder_aliases_are_real_inputs():
    text = read(BUILD_INPUT)
    for needle in [
        'Enum.KeyCode.Backspace', 'Enum.KeyCode.Escape', 'Enum.KeyCode.D',
        'Enum.KeyCode.T', 'Enum.KeyCode.M', 'Enum.UserInputType.MouseWheel',
        'UserInputService:GetFocusedTextBox()', 'callbacks.Rotate()',
        'callbacks.SelectSlot',
    ]:
        assert needle in text, f'missing builder QoL alias: {needle}'


def test_quick_swap_has_progress_feedback_and_aliases():
    text = read(QUICK_SWAP)
    for needle in [
        'CooldownProgress', 'MouseButton4', 'Alt', 'GMQoL_QuickSwapCompact',
        'GMQoL_QuickSwapHints', 'GMQoL_SafeMargin', 'showToast',
        'READY', 'PROFILE LOADING',
    ]:
        assert needle in text, f'missing quick-swap QoL behavior: {needle}'


def test_trade_has_keyboard_navigation_progress_and_feedback():
    text = read(TRADE)
    for needle in [
        'TradeProgress', 'Enum.KeyCode.Escape', 'Enum.KeyCode.F5',
        'Enum.KeyCode.Left', 'Enum.KeyCode.Right', 'Enum.KeyCode.Up',
        'Enum.KeyCode.Down', 'Enum.KeyCode.Return', 'GMQoL_TradeCompact',
        'showToast', 'BUSY',
    ]:
        assert needle in text, f'missing trade QoL behavior: {needle}'


def test_weapon_releases_inputs_when_focus_is_lost():
    text = read(WEAPON)
    assert 'WindowFocusReleased' in text
    assert 'releaseHeldActions()' in text
