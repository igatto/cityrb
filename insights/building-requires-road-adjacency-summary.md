# Building Requires Road Adjacency Summary

## What Changed

1. Added backend validation so `tile_2` placements must be orthogonally adjacent to at least one road tile: `road_col`, `road_row`, or `road_cross`.
2. Updated the frontend build flow to reject non-adjacent building placements before sending a request.
3. Added a short red flash on the target ground tile when a building placement is rejected on the frontend.
4. Tightened the create endpoint so occupied cells are rejected for normal placement requests, while road cells can still be upgraded to `road_cross`.
5. Expanded model and integration test coverage for valid adjacency, invalid adjacency, occupied-tile rejection, and road-cross upgrades.

## Files Updated

- `app/models/building_placement.rb`
- `app/controllers/building_placements_controller.rb`
- `app/javascript/pixi_app.js`
- `test/models/building_placement_test.rb`
- `test/integration/building_placements_test.rb`

## Behavior

- Buildings can only be placed on empty cells that have a road directly above, below, left, or right.
- Diagonal roads do not satisfy the adjacency rule.
- Invalid building clicks do not persist anything and briefly flash the tile red.
- Road placement behavior is unchanged.
- Existing road cells can still be updated to `road_cross`.

## Verification

- Ran `bin/rails test`
- Result: 11 tests, 0 failures
