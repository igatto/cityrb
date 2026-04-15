class CreateBuildingPlacements < ActiveRecord::Migration[8.1]
  def change
    create_table :building_placements do |t|
      t.integer :row, null: false
      t.integer :col, null: false
      t.string :building_key, null: false

      t.timestamps
    end

    add_index :building_placements, [:row, :col], unique: true
  end
end
