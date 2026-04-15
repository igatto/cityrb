class BuildingPlacementsController < ApplicationController
  rescue_from ActiveRecord::RecordNotUnique, with: :render_occupied_tile

  def index
    render json: BuildingPlacement.order(:row, :col).map { |placement| serialize_placement(placement) }
  end

  def create
    placement = BuildingPlacement.new(building_placement_params)

    if placement.save
      render json: serialize_placement(placement), status: :created
    else
      render json: { errors: placement.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def building_placement_params
    params.require(:building_placement).permit(:row, :col, :building_key)
  end

  def serialize_placement(placement)
    placement.slice(:id, :row, :col, :building_key)
  end

  def render_occupied_tile
    render json: { errors: [ "Tile is already occupied" ] }, status: :unprocessable_entity
  end
end
