# Road Crossings

## Goal

When dragging a new road over a cell that already has a road of the perpendicular axis, replace that cell with a crossroad tile. Ghost preview shows the crossroad during drag; on pointer-up the permanent sprite and server record are updated.

## Tilesheet

The crossroad tile is at column 0, row 2 → `tileFrame(0, 2)`.

## Key Design Decisions

- **Track building key per cell** — `placedBuildingsByCell` currently stores only sprites. We need to know what tile is at each cell to detect perpendicular roads. Change the map to store `{ sprite, buildingKey }` objects.
- **Ghost can overwrite existing road** — unlike the current `handleRoadTilePaint` which skips any already-placed cell, crossing detection requires painting over perpendicular cells with a crossroad ghost. Track the original key so it can be restored if the drag is cancelled (mode switch / escape).
- **Persist as update, not insert** — the cell already has a server record. Send a PATCH (or POST with upsert) to change its `building_key` to `road_cross`. The simplest approach is to re-use the existing `persistBuildingPlacement` POST and let the server upsert on `(board_id, row, col)`.
- **No new ghost type needed** — the existing ghost mechanism (alpha 0.6 on groundSprite, stored in `roadState.ghostSprites`) works. We just let it fire for perpendicular cells too, with `road_cross` as the key.

## Changes

### `app/models/building_placement.rb`

Add `road_cross` to `BUILDING_KEYS`:

```ruby
BUILDING_KEYS = %w[tile_2 road_col road_row road_cross].freeze
```

### `app/javascript/pixi_app.js`

#### 1. Add crossroad texture

```js
const roadCrossTexture = new Texture({ source: baseTexture.source, frame: tileFrame(0, 2) })
```

Register it:

```js
road_cross: roadCrossTexture,
```

#### 2. Change `placedBuildingsByCell` to store `{ sprite, buildingKey }`

Every read/write of `placedBuildingsByCell` must change:

- `renderBuilding`: store `{ sprite, buildingKey }` instead of bare sprite.
- `handleTileTap` (build mode): read `.sprite` from the map value before checking `.has()`.
- `handlePointerUp` (road commit): read `.sprite` from the map value.
- Any `.has()` checks remain on the map key; `.get().sprite` replaces the bare sprite reference.

#### 3. Helper: `isPerpendicularRoad(existingKey, newAxis)`

```js
const isPerpendicularRoad = (existingKey, newAxis) => {
  if (newAxis === "col") return existingKey === "road_row"
  if (newAxis === "row") return existingKey === "road_col"
  return false
}
```

#### 4. Update `handleRoadTilePaint` to handle crossings

```js
const handleRoadTilePaint = (row, col, buildingKey) => {
  const key = cellKey(row, col)
  if (roadState.ghostSprites.has(key)) return

  const existing = placedBuildingsByCell.get(key)
  const effectiveKey = existing && isPerpendicularRoad(existing.buildingKey, roadState.axis)
    ? "road_cross"
    : buildingKey

  // Skip non-road, non-crossing occupied cells
  if (existing && effectiveKey === buildingKey) return

  const texture = texturesByKey[effectiveKey]
  if (!texture) return

  const groundSprite = groundSpritesByCell.get(key)
  if (groundSprite) {
    const originalTexture = groundSprite.texture
    groundSprite.texture = texture
    groundSprite.alpha = 0.6
    roadState.ghostSprites.set(key, {
      sprite: groundSprite,
      row,
      col,
      buildingKey: effectiveKey,
      originalTexture,
      wasPlaced: !!existing,           // true → update existing, don't re-add to placedBuildingsByCell
      originalBuildingKey: existing?.buildingKey,
    })
  }
}
```

#### 5. Update `handlePointerUp` to handle crossing commits

```js
roadState.ghostSprites.forEach(({ sprite, row, col, buildingKey, wasPlaced }) => {
  sprite.alpha = 1
  placedBuildingsByCell.set(cellKey(row, col), { sprite, buildingKey })
  persistBuildingPlacement({ row, col, buildingKey }).catch((error) => {
    console.error("Failed to persist road placement", error)
  })
})
```

`wasPlaced` cells get their map entry overwritten with the new `road_cross` key. The POST endpoint already upserts by `(board_id, row, col)` so no backend change is needed beyond the allowed key list.

#### 6. Update `clearRoadGhosts` to restore crossed cells

When ghosts are cleared (drag cancelled), cells that were already placed (`wasPlaced: true`) must have their texture restored:

```js
const clearRoadGhosts = () => {
  roadState.ghostSprites.forEach(({ sprite, wasPlaced, originalTexture, originalBuildingKey }) => {
    sprite.alpha = 1
    if (wasPlaced) {
      sprite.texture = originalTexture  // restore previous road texture
    } else {
      boardContainer.removeChild(sprite)
      sprite.destroy()
    }
  })
  roadState.ghostSprites.clear()
}
```

Wait — the current ghost mechanism reuses `groundSpritesByCell` sprites (not separate ghost sprites). `clearRoadGhosts` currently destroys non-ground sprites and restores ground sprites. Let me re-examine:

Looking at `handleRoadTilePaint`: it always uses `groundSpritesByCell.get(key)` — so it always modifies the existing ground tile sprite in place, storing `originalTexture` for restoration. The `clearRoadGhosts` currently only calls `boardContainer.removeChild(sprite); sprite.destroy()` for sprites not found in `groundSpritesByCell`.

So the correct clearing for `wasPlaced` cells is: restore `sprite.texture = originalTexture` and `sprite.alpha = 1` (the ground sprite approach already handles this since the ghost IS the ground sprite). The existing clearRoadGhosts already does the right thing — it only destroys sprites that came from `boardContainer.addChild` directly. Cells with a `groundSprite` just get their `originalTexture` restored.

The key update needed in `clearRoadGhosts` is: for `wasPlaced` cells (crossing ghosts), make sure alpha goes back to 1 and texture is restored — which the existing logic already does via the `groundSpritesByCell` path. No change needed to `clearRoadGhosts`.

## Implementation Steps

1. Add `road_cross` to `BUILDING_KEYS` in `building_placement.rb`.
2. Add `roadCrossTexture` extraction and registration in `pixi_app.js`.
3. Refactor `placedBuildingsByCell` to store `{ sprite, buildingKey }` — update all read/write sites.
4. Add `isPerpendicularRoad` helper.
5. Update `handleRoadTilePaint` to detect perpendicular crossings and use `road_cross` key.
6. Update `handlePointerUp` to write `{ sprite, buildingKey }` to `placedBuildingsByCell`.
7. Verify `clearRoadGhosts` restores textures correctly for crossing ghosts (should work via existing `originalTexture` mechanism).

## What Is Not Changing

- Server endpoint — already upserts; `road_cross` just needs to be a valid key.
- Ghost mechanism — reuses existing `groundSpritesByCell` sprite mutation pattern.
- Axis locking, `R`-key rotation, drag threshold — untouched.
- Building placement mode — untouched.
