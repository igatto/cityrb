class PagesController < ApplicationController
  def index
    @building_placements = BuildingPlacement.order(:row, :col)
  end
end
