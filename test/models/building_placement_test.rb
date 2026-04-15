require "test_helper"

class BuildingPlacementTest < ActiveSupport::TestCase
  test "is valid with in-bounds coordinates and supported building key" do
    placement = BuildingPlacement.new(row: 3, col: 4, building_key: "tile_2")

    assert placement.valid?
  end

  test "rejects out-of-bounds coordinates" do
    placement = BuildingPlacement.new(row: 10, col: -1, building_key: "tile_2")

    assert_not placement.valid?
    assert_includes placement.errors[:row], "is not included in the list"
    assert_includes placement.errors[:col], "is not included in the list"
  end

  test "rejects unsupported building key" do
    placement = BuildingPlacement.new(row: 1, col: 1, building_key: "town_hall")

    assert_not placement.valid?
    assert_includes placement.errors[:building_key], "is not included in the list"
  end

  test "rejects duplicate placements on the same tile" do
    BuildingPlacement.create!(row: 2, col: 5, building_key: "tile_2")
    duplicate = BuildingPlacement.new(row: 2, col: 5, building_key: "tile_2")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:row], "has already been taken"
  end
end
