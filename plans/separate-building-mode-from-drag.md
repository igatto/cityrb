# Plan: Separate Building Placement From Board Dragging

## Goal

Add a simple interface in the bottom-left corner with a `Building` button that switches the board into build mode, so placing a building and dragging the board are two separate actions.

## Problem Summary

Current behavior mixes tile placement with the same pointer flow used for board dragging:

- the board is always listening for drag input
- tile placement is still tied to tile `pointertap`
- left-click interaction does not have a dedicated "build mode"

As a result, dragging works, but placing a building does not behave as a separate, reliable action.

## Target UX

- Default mode is `pan`.
- A small control panel is fixed in the bottom-left corner of the board area.
- The panel contains one button labeled `Building`.
- Clicking `Building` enables `build` mode.
- In `build` mode, clicking an empty tile places the building and persists it.
- In `pan` mode, dragging moves the board and clicking does not place anything.
- The active mode is visually obvious.

Recommended first version:

- `pan` is active by default
- `Building` acts as a toggle
- after a successful placement, stay in `build` mode until the user turns it off

If you want fewer accidental placements, the only behavior change would be switching back to `pan` after each placement.

## Scope

- Add the bottom-left build control UI.
- Introduce explicit interaction mode state.
- Update placement logic to run only in `build` mode.
- Keep drag and zoom behavior intact in `pan` mode.
- Keep existing persistence flow for saved buildings.

## Implementation Steps

### 1. Add a HUD wrapper around the Pixi canvas

Update `app/views/pages/index.html.erb` so the board area can host both:

- the Pixi canvas
- an overlay control panel

Recommended structure:

- outer board shell with `position: relative`
- existing `#pixi-canvas`
- a bottom-left overlay container for controls

This keeps the UI in regular Rails/HTML instead of trying to draw buttons inside Pixi.

### 2. Style a simple bottom-left control

Update `app/assets/stylesheets/application.css` to:

- keep the board dimensions as they are now
- position the control panel at the lower-left corner
- give the `Building` button clear active/inactive states
- keep the overlay above the canvas with `position: absolute` and a higher stacking order

The control should be intentionally minimal:

- one button
- compact padding
- readable contrast
- no modal or floating menu yet

### 3. Move interaction mode into the Stimulus controller

Extend `app/javascript/controllers/pixi_controller.js` so it owns a small state machine:

- `mode = "pan"` by default
- `setMode("build")`
- `setMode("pan")`
- `toggleBuildMode()`

Stimulus should also:

- listen for clicks on the `Building` button
- update button styling/accessibility state
- pass the current mode into the Pixi app

Recommended contract:

- `initPixiApp(...)` returns an object with `setInteractionMode(mode)`
- Stimulus calls that method whenever the button is toggled

This keeps DOM/UI concerns out of `pixi_app.js`.

### 4. Make Pixi placement logic mode-aware

Update `app/javascript/pixi_app.js` so placement is gated by explicit mode, not just by tap eligibility.

Add:

- `interactionMode = "pan"` local state
- `setInteractionMode(mode)` setter exposed on the returned app object

Then change placement checks so `handleTileTap(row, col)` immediately returns unless:

- `interactionMode === "build"`
- the tile is not occupied
- the tile is not already being persisted
- the input was a real click, not a drag

This is the key separation that is missing right now.

### 5. Keep drag behavior active only for panning

Refine the existing DOM pointer handlers:

- in `pan` mode: current drag behavior stays enabled
- in `build` mode: dragging should not move the camera

Practical approach:

- keep the existing pointer listeners
- branch early in `handlePointerDown` / `handlePointerMove`
- only start drag state when `interactionMode === "pan"`

This avoids camera movement while the user is trying to place a building.

### 6. Keep tile clicks active only for building

Ground tiles can stay interactive, but the tile click handler should only do work in `build` mode.

That means:

- do not remove tile metadata or persistence logic
- do not rely on drag state alone to infer intent
- do not place anything from normal clicks while in `pan`

The current `pointertap` hook can remain if it is guarded by the new mode state. If it proves unreliable with DOM-level pointer listeners, replace it with a board click resolution method later.

### 7. Preserve existing persistence flow

The persistence pieces added earlier are still valid:

- POST to `/building_placements`
- prevent duplicate submissions with `pendingPlacements`
- render saved placements on load

This plan changes interaction control, not the storage model.

### 8. Add basic accessibility and feedback

For the `Building` button:

- reflect active state with a CSS class
- add `aria-pressed="true|false"`
- optionally show a small label like `Mode: Build` or `Mode: Pan`

The minimum acceptable first version is the active button state alone.

## Suggested File Changes

- `app/views/pages/index.html.erb`
  Add the board wrapper and bottom-left control markup.
- `app/assets/stylesheets/application.css`
  Add overlay positioning and button state styles.
- `app/javascript/controllers/pixi_controller.js`
  Own mode state and connect the button to the Pixi app.
- `app/javascript/pixi_app.js`
  Gate drag and placement behavior behind explicit interaction mode.

## Verification Checklist

- [ ] The page shows a simple bottom-left `Building` button.
- [ ] The board starts in `pan` mode.
- [ ] Dragging the mouse moves the board in `pan` mode.
- [ ] Clicking tiles in `pan` mode does not place buildings.
- [ ] Clicking `Building` switches to `build` mode and updates button styling.
- [ ] Clicking an empty tile in `build` mode places and persists one building.
- [ ] Dragging in `build` mode does not move the board.
- [ ] Clicking an occupied tile still does not create duplicates.
- [ ] Reloading the page still restores saved buildings.
- [ ] Zoom still works after the interaction split.

## Nice Follow-Ups

- Add a dedicated `Pan` button instead of a toggle if you want mode switching to be more explicit.
- Add more build buttons once multiple building types exist.
- Add a temporary ghost preview on hover while in `build` mode.
