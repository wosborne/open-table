class ViewsController < TablesController
  include SearchAndFilterable

  def show
    @view = current_table.views.friendly.find(params[:id])
    @table = @view.table
    @items = search_and_filter_items(item_scope)
    @property_value_options = property_value_options
  end

  def create
    @view = current_table.views.new(name: "New View")

    if @view.save
      redirect_to account_table_view_path(current_account, current_table, @view), notice: "View was successfully created."
    else
      redirect_to account_table_path(current_account, current_table), alert: "Failed to create view."
    end
  end

  def update
    @view = current_view

    if @view.update(view_params)
      redirect_to account_table_view_path(current_account, current_table, @view), notice: "View was successfully updated."
    else
      redirect_to account_table_path(current_account, current_table), alert: "Failed to update view."
    end
  end

  def destroy
    if current_view.destroy
      redirect_to account_table_path(current_account, current_table), notice: "View was successfully deleted."
    else
      redirect_to account_table_view_path(current_account, current_table, current_view), alert: "Failed to delete view."
    end
  end

  def filter_field
    property = current_table.properties.find(params[:property_id])
    index = params[:index]
    render partial: "components/tabs/filter_input", locals: { property:, value: nil, index: }
  end

  private

  def view_params
    params.require(:view).permit(:name, filters_attributes: [ :id, :property_id, :value, :_destroy ])
  end

  def property_value_options
    properties.select_type.map do |property|
      { property.id => property.all_values }
    end
  end

  def item_scope
    @item_scope||= apply_view_filters
  end

  def apply_view_filters
    items = current_table.items.order(:created_at)

    @view.filters.each do |filter|
      pid = filter.property_id

      items = items.where("properties ->> ? ILIKE ?", pid.to_s, "%#{filter.value}%")
    end

    items
  end
end
