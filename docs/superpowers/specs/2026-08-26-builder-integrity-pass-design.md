# Builder Integrity Pass Design

## Goal
Make Workshop placement feedback trustworthy: a green/ready ghost should use the same clearance geometry as the server, blocked snaps should fall through to another compatible node when possible, and the local builder should not be rejected merely because the builder avatar overlaps the placement volume.

## Current failure modes

1. `BuildPreview` marks free placement as `FREE` without checking world overlap, while `BuildService` later performs `_clearance` and can reject it as `Collision`.
2. For snapped placement, the preview selects the nearest compatible target socket and immediately reports `SNAP`; it does not test the snapped transform for clearance. A nearer blocked socket can therefore hide a slightly farther valid socket.
3. The server clearance query includes the requesting player's character. Building close to the avatar can be rejected even when the machine geometry itself is valid.
4. Client and server currently duplicate the clearance-size assumption implicitly rather than sharing one source of truth.

## Design

### Shared clearance geometry
Add `BuildMath.ClearanceSize(size, inset)` returning the axis-aligned query size used by both client and server. The default inset remains `0.08` studs to preserve the existing intentional contact tolerance.

### Preview clearance
`BuildPreview` gets a `_hasClearance(transform)` helper using `Workspace:GetPartBoundsInBox`. Its exclusion list contains the preview ghost, the local player's character, and the client-only node-marker folder. This mirrors server intent while preventing client-only visuals from invalidating placement.

For snapped placement, `_findCompatiblePair` will evaluate compatible target sockets in pointer-distance order. For each candidate it will compute the authoritative-equivalent snap transform and return the first candidate that also passes preview clearance. A blocked nearer node no longer prevents use of a valid nearby node.

For free placement, the preview reports a new `BLOCKED` state when the free transform overlaps world geometry. `GetPlacement` will therefore refuse the request before the remote is invoked.

### Server clearance parity
`BuildService:_clearance` will use `BuildMath.ClearanceSize`. Placement calls will exclude only the requesting player's character from collision checks. Existing machine geometry, other machines, terrain/build surfaces, and other world obstacles remain authoritative blockers.

### UI feedback
`BuildController` maps `BLOCKED` to a clear `PLACEMENT BLOCKED` message and keeps the ghost in the invalid visual state.

## Constraints

- Preserve the public 100-part catalogue.
- Preserve server-authoritative mutations.
- Preserve node compatibility, mirroring, rotation, undo/redo, duplicate, inventory, and blueprint behavior.
- Do not weaken collision checks against machine/world geometry.
- Do not modify combat, piloting, trading, or camera behavior.

## Verification

Add a source-contract regression test requiring shared clearance sizing, client collision prediction, blocked-node fallthrough, avatar exclusion on the authoritative placement path, and `BLOCKED` UI feedback. Run the builder regression tests plus the repository invariant suite before merge.