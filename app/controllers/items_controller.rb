class ItemsController < TablesController
  def create
    @item = current_table.items.create
  end

  def set_property
    current_item.set_property(property_params)

    render turbo_stream: [
      turbo_stream.replace("item-#{current_item.id}-property-#{property.id}", partial: "tables/cell", locals: { item: current_item, property:, value: current_item.properties[property.id.to_s] })
    ]
  end

  helper_method :current_item
  def current_item
    @current_item ||= current_table.items.find(params[:item_id] || params[:id])
  end

  private
  def property_params
    params.require(:item).permit(:property_id, :value)
  end

  def property
    @property ||= current_table.properties.find(property_params[:property_id])
  end
end
