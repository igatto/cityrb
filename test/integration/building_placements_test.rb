require "test_helper"

class BuildingPlacementsTest < ActionDispatch::IntegrationTest
  test "gets saved placements as json" do
    BuildingPlacement.create!(row: 1, col: 6, building_key: "road_row")
    BuildingPlacement.create!(row: 1, col: 7, building_key: "tile_2")
    BuildingPlacement.create!(row: 4, col: 1, building_key: "road_row")
    BuildingPlacement.create!(row: 4, col: 2, building_key: "tile_2")

    get building_placements_url, as: :json

    assert_response :success
    placements = BuildingPlacement.order(:row, :col).to_a
    assert_equal [
      { "id" => placements[0].id, "row" => 1, "col" => 6, "building_key" => "road_row" },
      { "id" => placements[1].id, "row" => 1, "col" => 7, "building_key" => "tile_2" },
      { "id" => placements[2].id, "row" => 4, "col" => 1, "building_key" => "road_row" },
      { "id" => placements[3].id, "row" => 4, "col" => 2, "building_key" => "tile_2" }
    ], response.parsed_body
  end

  test "creates a placement" do
    BuildingPlacement.create!(row: 3, col: 3, building_key: "road_row")

    assert_difference("BuildingPlacement.count", 1) do
      post building_placements_url,
           params: {
             building_placement: {
               row: 3,
               col: 4,
               building_key: "tile_2"
             }
           },
           as: :json
    end

    assert_response :created
    assert_equal({ "row" => 3, "col" => 4, "building_key" => "tile_2" }, response.parsed_body.slice("row", "col", "building_key"))
  end

  test "rejects a building placement without an adjacent road" do
    assert_no_difference("BuildingPlacement.count") do
      post building_placements_url,
           params: {
             building_placement: {
               row: 3,
               col: 4,
               building_key: "tile_2"
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "must be placed adjacent to a road"
  end

  test "rejects an occupied tile" do
    BuildingPlacement.create!(row: 3, col: 3, building_key: "road_row")
    BuildingPlacement.create!(row: 3, col: 4, building_key: "tile_2")

    assert_no_difference("BuildingPlacement.count") do
      post building_placements_url,
           params: {
             building_placement: {
               row: 3,
               col: 4,
               building_key: "tile_2"
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Row has already been taken"
  end

  test "updates a perpendicular road to a crossroad" do
    BuildingPlacement.create!(row: 3, col: 4, building_key: "road_row")

    assert_no_difference("BuildingPlacement.count") do
      post building_placements_url,
           params: {
             building_placement: {
               row: 3,
               col: 4,
               building_key: "road_cross"
             }
           },
           as: :json
    end

    assert_response :created
    assert_equal "road_cross", BuildingPlacement.find_by!(row: 3, col: 4).building_key
    assert_equal({ "row" => 3, "col" => 4, "building_key" => "road_cross" }, response.parsed_body.slice("row", "col", "building_key"))
  end
end
