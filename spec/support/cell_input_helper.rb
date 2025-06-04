module CellInputHelper
  def find_cell_input(item_id, property_id)
    find("[data-item-id='#{item_id}'][data-property-id='#{property_id}']")
  end
end
