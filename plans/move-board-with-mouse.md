# Plan: Move Isometric Board With Mouse

## Goal

Enable the user to click-and-drag the mouse to move (pan) the isometric board smoothly in any direction.

## Scope

- Add mouse drag panning for desktop.
- Keep existing zoom and board rendering behavior intact.
- Avoid accidental drag when the user only clicks.

## Implementation Steps

### 1. Add camera drag state

In `app/javascript/pixi_app.js`, define a small state object near camera setup:

- `isDragging` (`boolean`)
- `lastPointerX` (`number`)
- `lastPointerY` (`number`)
- Optional: `dragThreshold` (`number`, e.g. `3`)

This keeps pointer movement logic predictable and easy to debug.

### 2. Make stage/canvas pointer-interactive

Ensure the interactive target can receive pointer events everywhere:

- Use stage hit area (`app.stage.hitArea = app.screen`) and `eventMode = "static"` (or equivalent in your current code).
- Register handlers for:
  - `pointerdown`
  - `pointermove`
  - `pointerup`
  - `pointerupoutside`

If handlers already exist, keep one source of truth and avoid duplicate listeners.

### 3. Implement drag-to-pan behavior

On `pointerdown`:

- Set `isDragging = true`
- Capture current global pointer position as `lastPointerX/Y`

On `pointermove` (only when dragging):

- Read current global pointer position
- Compute deltas:
  - `dx = currentX - lastPointerX`
  - `dy = currentY - lastPointerY`
- Move camera container:
  - `camera.x += dx`
  - `camera.y += dy`
- Update `lastPointerX/Y`

On `pointerup` and `pointerupoutside`:

- Set `isDragging = false`

### 4. Prevent default browser drag side effects

On the canvas element:

- Disable text/image drag behavior while interacting.
- Optionally set cursor styles:
  - idle: `grab`
  - dragging: `grabbing`

This improves user feedback and prevents browser-native drag interference.

### 5. Keep zoom compatible with panning

If wheel-zoom is already implemented:

- Do not reset camera position during zoom.
- Keep zoom centered on cursor by preserving current world point math.
- Confirm drag continues to feel correct after zooming in/out.

## Edge Cases

- Releasing mouse outside the canvas should still stop dragging (`pointerupoutside`).
- Fast mouse movement should not “jump” camera (always update last pointer each move).
- Drag should work at any zoom level.
- Click without movement should not cause visible camera shift.

## Verification Checklist

- [ ] Click-drag moves board in all directions.
- [ ] Releasing outside canvas ends drag state.
- [ ] No console errors during drag.
- [ ] Existing tile depth/order and rendering remain unchanged.
- [ ] Zoom still works and combines correctly with drag.
- [ ] Cursor changes between `grab` and `grabbing` (if implemented).

## Optional Enhancements

- Add inertial panning (momentum after release).
- Add camera bounds so user cannot pan infinitely off-map.
- Add right-mouse-button-only pan mode if left click will later select tiles.
