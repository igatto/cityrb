class BuildingPlacement < ApplicationRecord
  BOARD_SIZE = 10
  BUILDING_KEYS = %w[tile_2 road_col road_row road_cross].freeze
  ROAD_KEYS = %w[road_col road_row road_cross].freeze

  validates :row, :col, :building_key, presence: true
  validates :row, inclusion: { in: 0...BOARD_SIZE }, uniqueness: { scope: :col }
  validates :col, inclusion: { in: 0...BOARD_SIZE }
  validates :building_key, inclusion: { in: BUILDING_KEYS }
  validate :road_adjacent, if: :tile?

  private

  def tile?
    building_key == "tile_2"
  end

  def road_adjacent
    neighbors = [
      [ row - 1, col ],
      [ row + 1, col ],
      [ row, col - 1 ],
      [ row, col + 1 ]
    ].select { |neighbor_row, neighbor_col| neighbor_row.between?(0, BOARD_SIZE - 1) && neighbor_col.between?(0, BOARD_SIZE - 1) }

    adjacent_road = neighbors.any? do |neighbor_row, neighbor_col|
      BuildingPlacement.exists?(row: neighbor_row, col: neighbor_col, building_key: ROAD_KEYS)
    end

    errors.add(:base, "must be placed adjacent to a road") unless adjacent_road
  end
end
