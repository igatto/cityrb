class BuildingPlacementsController < ApplicationController
  def index
    render json: BuildingPlacement.order(:row, :col).map { |placement| serialize_placement(placement) }
  end

  def destroy_all
    BuildingPlacement.destroy_all
    head :no_content
  end

  def create
    placement = BuildingPlacement.find_by(
      row: building_placement_params[:row],
      col: building_placement_params[:col]
    )

    if placement
      if road_cross_upgrade?(placement, building_placement_params[:building_key])
        placement.building_key = building_placement_params[:building_key]
      else
        duplicate_placement = BuildingPlacement.new(building_placement_params)
        duplicate_placement.valid?
        render json: { errors: duplicate_placement.errors.full_messages }, status: :unprocessable_entity
        return
      end
    else
      placement = BuildingPlacement.new(building_placement_params)
    end

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

  def road_cross_upgrade?(placement, building_key)
    building_key == "road_cross" && placement.building_key.in?(BuildingPlacement::ROAD_KEYS)
  end

  def serialize_placement(placement)
    placement.slice(:id, :row, :col, :building_key)
  end
end
