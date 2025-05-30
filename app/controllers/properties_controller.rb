class PropertiesController < TablesController
  def create
    @property = current_table.properties.create(data_type: :text)

    redirect_to account_table_path(current_account, current_table)
  end

  def update
    @property = current_table.properties.find(params[:id])

    @property.update(property_params)
  end

  def type_fields
    property = current_table.properties.find(params[:id])
    render partial: "tables/properties/type_fields", locals: { property:, f: nil }
  end

  def refresh_cells
    property = current_table.properties.find(params[:id])
    item_ids = params[:item_ids]
    items = current_table.items.where(id: item_ids)

    render turbo_stream: items.map { |item|
      turbo_stream.replace(
        "item-#{item.id}-property-#{property.id}",
        partial: "tables/cell",
        locals: { item: item, property: property, value: item.properties[property.id.to_s] }
      )
    }
  end

  def set_positions
    cleansed_position_ids.each_with_index do |id, index|
      current_table.properties.find(id).update(position: index)
    end

    redirect_to params[:return_path] || account_table_path(current_account, current_table)
  end

  private
  def property_params
    params.require(:property).permit(:id, :name, :data_type, :position, :linked_table_id, options_attributes: [ :id, :value, :_destroy ])
  end

  def cleansed_position_ids
    param_ids = params[:positions].split(",") || []
    param_ids.select! { |val| val.match?(/\A\d+\z/) }
    param_ids.map!(&:to_i)
    param_ids.uniq!
    param_ids.reject(&:zero?)
  end
end
