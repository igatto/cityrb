# Road Tile Rendering Artifact Fix

## Problem

Road tiles displayed a small ground-colored artifact at the top-left corner of the isometric diamond. The user described it as "1 px of ground tile" showing on the top-left side of placed road tiles.

## Investigation

### Tilesheet v2 Applied

Switched from `tilesheet.png` to `tilesheet_v2.png`, which has:
- Tile width: 134px, tile height: 128px
- Tile margin: 2px, tile spacing: 4px

Introduced a `tileFrame(col, row)` helper in `pixi_app.js`:
```js
const tileFrame = (col, row) => new Rectangle(2 + col * 138, 2 + row * 132, TILE_WIDTH, TILE_HEIGHT)
```

Tile layout (row, col):
- `(0, 0)` — ground
- `(0, 1)` — building (tile_2)
- `(1, 1)` — road_col
- `(1, 3)` — road_row

### Root Cause: Road Tile Art Has Transparent Diamond Edge

Pixel analysis (PNG decoded manually with filter reconstruction) revealed:

At `dy=24` from the tile top, the **road_col tile is transparent** at `dx=44–52` — the same area where the ground tile has its anti-aliased diamond edge (`R` = semi-transparent beige edge pixel).

```
ground  dy=24: ...........RggggggggggR...........  ← edge at dx=44
road_col dy=24: .............gggggggggR...........  ← transparent dx=44–52
```

This 8px triangular gap (between `dy=20` and `dy=28`) is caused by the road stripe art replacing/omitting the diamond's left edge pixels. The road tile simply was not drawn to cover the same diamond footprint as the ground tile.

The previous approach — rendering a road sprite **on top** of the ground sprite at the same position — exposed the ground sprite through those transparent road pixels.

Attempted and rejected fixes:
- Moving the texture frame x-offset by 1px — wrong level, no effect on art content
- `roundPixels: true` in PixiJS app init — made rendering worse (misaligned grid)

## Solution: In-Place Texture Swap

Instead of layering a road sprite over a ground sprite, **replace the ground sprite's texture directly**. Since both sprites share the same position, anchor, and size, swapping the texture eliminates the layering entirely — no transparent overlap, no ground bleed-through.

### Changes in `pixi_app.js`

1. **Track ground sprites** in a new `groundSpritesByCell` map (populated during board generation).

2. **`renderBuilding`** — for `road_*` keys, swap the ground sprite's texture instead of creating a new sprite:
```js
if (buildingKey.startsWith("road_")) {
  const groundSprite = groundSpritesByCell.get(key)
  if (groundSprite) {
    groundSprite.texture = texture
    placedBuildingsByCell.set(key, groundSprite)
    return groundSprite
  }
}
```

3. **`handleRoadTilePaint`** (ghost preview) — swap the ground sprite's texture temporarily, storing `originalTexture` for restoration:
```js
const originalTexture = groundSprite.texture
groundSprite.texture = texture
groundSprite.alpha = 0.6
roadState.ghostSprites.set(key, { sprite: groundSprite, row, col, buildingKey, originalTexture })
```

4. **`clearRoadGhosts`** — restore the original texture on cancel:
```js
if (originalTexture !== undefined) {
  sprite.texture = originalTexture
  sprite.alpha = 1
} else {
  boardContainer.removeChild(sprite)
  sprite.destroy()
}
```

5. **`handlePointerUp`** — on road placement confirmation, `sprite.alpha = 1` and register in `placedBuildingsByCell` (texture is already swapped from the ghost step).

## Result

Road tiles render without any ground artifact. Both the ghost preview (semi-transparent during drag) and confirmed placements use the texture swap approach, so neither has the bleed issue.
