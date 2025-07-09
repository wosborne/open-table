module CellInputHelper
  def find_cell_input(record_id, property_id)
    find("[data-record-id='#{record_id}'][data-property-id='#{property_id}']")
  end
end
