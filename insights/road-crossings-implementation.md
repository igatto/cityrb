# Road Crossings Implementation

## Goal

When dragging a road over a cell that already has a perpendicular road, replace that cell with a crossroad tile (`road_cross`). Ghost preview shows the crossing during drag; on pointer-up the permanent sprite and server record are committed.

## Changes Made

### `app/models/building_placement.rb`

Added `road_cross` to `BUILDING_KEYS` so the server accepts it as a valid building key (the POST endpoint already upserts by `(board_id, row, col)`, so no further backend changes were needed).

### `app/javascript/pixi_app.js`

**1. New texture**

Extracted `roadCrossTexture` at `tileFrame(0, 2)` (column 0, row 2 of the tilesheet) and registered it under `road_cross` in `texturesByKey`.

**2. `placedBuildingsByCell` refactored to store `{ sprite, buildingKey }`**

Previously the map stored bare sprite references. To detect perpendicular crossings, we need to know what tile is at each cell. All read/write sites were updated:
- `renderBuilding`: stores `{ sprite, buildingKey }` and returns `.sprite` on early-return hit.
- `handlePointerUp`: writes `{ sprite, buildingKey }` when committing ghost sprites.

**3. `isPerpendicularRoad(existingKey, newAxis)` helper**

Returns `true` when the existing cell holds a road on the opposite axis from the one being drawn.

**4. `handleRoadTilePaint` updated for crossing detection**

- Removed the early-return that skipped all already-placed cells.
- Checks if the existing cell is a perpendicular road; if so, uses `"road_cross"` as `effectiveKey`.
- Non-road occupied cells (buildings) are still skipped.
- Ghost entry now includes `wasPlaced` and `originalBuildingKey` fields for potential restoration.

**5. `clearRoadGhosts` — no change needed**

The ghost mechanism already reuses ground sprites and stores `originalTexture`. Restoring crossed cells on drag-cancel works via the existing `sprite.texture = originalTexture` path.

## Key Design Insight

Road tiles reuse the ground sprite in-place (texture swap) to avoid transparency layering artifacts. This means the "ghost" for a crossing cell IS the already-placed ground sprite — so clearing ghosts naturally restores the previous road texture by reverting `originalTexture`, with no separate sprite management needed.

## What Was Not Changed

- Server endpoint (already upserts; `road_cross` only needed to be a valid key)
- Ghost alpha mechanism
- Axis locking, `R`-key rotation, drag threshold
- Building placement mode
