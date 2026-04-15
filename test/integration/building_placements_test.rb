require "test_helper"

class BuildingPlacementsTest < ActionDispatch::IntegrationTest
  test "gets saved placements as json" do
    BuildingPlacement.create!(row: 4, col: 2, building_key: "tile_2")
    BuildingPlacement.create!(row: 1, col: 7, building_key: "tile_2")

    get building_placements_url, as: :json

    assert_response :success
    assert_equal [
      { "id" => BuildingPlacement.order(:row, :col).first.id, "row" => 1, "col" => 7, "building_key" => "tile_2" },
      { "id" => BuildingPlacement.order(:row, :col).last.id, "row" => 4, "col" => 2, "building_key" => "tile_2" }
    ], response.parsed_body
  end

  test "creates a placement" do
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

  test "rejects an occupied tile" do
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
end
