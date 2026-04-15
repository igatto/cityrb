# Place Building and Persist Summary

## What Changed

1. Added a persisted `BuildingPlacement` model with:
   - `row`
   - `col`
   - `building_key`
   - a unique index on `[row, col]`
2. Added JSON endpoints for:
   - `GET /building_placements`
   - `POST /building_placements`
3. Updated `PagesController#index` to preload saved placements.
4. Passed the preloaded placements into the existing Pixi Stimulus controller.
5. Updated the Pixi board to:
   - extract the 2nd tilesheet tile as the building texture
   - render saved buildings on boot
   - place a building when a tile is clicked
   - persist the placement to Rails before rendering it permanently
   - ignore duplicate clicks on occupied or in-flight cells
   - avoid accidental placement during drag-to-pan interactions

## Files Added

- `app/models/building_placement.rb`
- `app/controllers/building_placements_controller.rb`
- `db/migrate/20260415180000_create_building_placements.rb`
- `test/models/building_placement_test.rb`
- `test/integration/building_placements_test.rb`

## Files Updated

- `app/controllers/pages_controller.rb`
- `app/views/pages/index.html.erb`
- `app/javascript/controllers/pixi_controller.js`
- `app/javascript/pixi_app.js`
- `config/routes.rb`
- `db/schema.rb`

## Behavior

- Clicking a tile places one building using the 2nd tile from `tilesheet.png`.
- The placement is saved in SQLite immediately.
- Reloading the page rehydrates previously saved buildings.
- Existing pan and zoom behavior remains in place.

## Verification

- Ran `bin/rails db:migrate`
- Ran `bin/rails test`
- Ran `env XDG_CACHE_HOME=tmp/cache bin/rubocop --no-server ...`

All of the above passed during implementation.
