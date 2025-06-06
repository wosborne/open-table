class TablesController < AccountsController
  include SearchAndFilterable
  before_action :set_current_view_in_session, only: [ :show ]

  def show
    @table = current_table
    @items = search_and_filter_items(item_scope)
    @property_value_options = property_value_options
    @view = current_view

    render "views/show"
  end

  def new
    @table = Table.new
  end

  def create
    @table = current_account.tables.new(table_params)
    if @table.save
      redirect_to account_table_path(current_account, @table), notice: "Table was successfully created."
    else
      render :new
    end
  end

  def index
    @tables = current_account.tables
  end

  def property_options
    property = current_table.properties.find(params[:property_id]) if params[:property_id].present?

    render turbo_stream: [
      turbo_stream.replace("filter-input", partial: "components/table/filter_input", locals: { property: property })
    ]
  end

  def set_record_attribute
    item = current_table.items.find(set_attribute_params[:item_id])
    property = current_table.properties.find(set_attribute_params[:property_id])
    item.set_property(set_attribute_params) if item && property

    render turbo_stream: [
      turbo_stream.replace("item-#{item.id}-property-#{property.id}", partial: "components/table/cell", locals: { item:, property:, value: item.properties[property.id.to_s] })
    ]
  end

  helper_method :current_table
  def current_table
    @current_table ||= current_account.tables.friendly.find(params[:table_id] || params[:id])
  end

  helper_method :current_view
  def current_view
    @current_view ||= current_table.views.friendly.find(session[:current_view_id])
  end

  private
  def item_scope
    current_table.items.order(:created_at)
  end

  def table_params
    params.require(:table).permit(:name, :import)
  end

  def set_attribute_params
    params.permit(:item_id, :property_id, :value)
  end

  def property_value_options
    properties.select_type.map do |property|
      { property.id => property.all_values }
    end
  end

  def set_current_view_in_session
    if params[:view_id]
      session[:current_view_id] = params[:view_id]
    elsif params[:controller] == "views" && params[:id] != nil
      session[:current_view_id] = params[:id]
    else
      session[:current_view_id] = current_table.views.first.id
    end
  end
end
