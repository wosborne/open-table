class AddLastItemIdToTable < ActiveRecord::Migration[8.0]
  def change
    add_column :tables, :last_item_id, :integer, default: 0
  end
end
