class PropertiesController < TablesController
  def create
    @property = current_table.properties.create(data_type: :text)

    redirect_to account_table_path(current_account, current_table)
  end

  def update
    @property = current_table.properties.find(params[:id])

    @property.update(property_params)
  end

  def destroy
    if current_property.destroy
      redirect_to account_table_path(current_account, current_table), notice: "Propety was successfully deleted."
    else
      redirect_to account_table_path(current_account, current_table), alert: "Failed to delete property."
    end
  end

  def type_fields
    property = current_table.properties.find(params[:id])
    render partial: "components/table/properties/type_fields", locals: { property:, f: nil }
  end

  def refresh_cells
    property = current_table.properties.find(params[:id])
    item_ids = JSON.parse(params[:item_ids])
    items = current_table.items.where(id: item_ids)

    render turbo_stream: items.map { |item|
      turbo_stream.replace(
        "item-#{item.id}-property-#{property.id}",
        partial: "components/table/cell",
        locals: { item: item, property: property, value: item.properties[property.id.to_s] }
      )
    }
  end

  helper_method :current_property
  def current_property
    @current_property ||= current_table.properties.find(params[:property_id] || params[:id])
  end

  private
  def property_params
    params.require(:property).permit(
      :id,
      :name,
      :data_type,
      :position,
      :linked_table_id,
      options_attributes: [ :id, :value, :_destroy ],
      formula_attributes: [ :id, :formula_data ]
    )
  end
end
