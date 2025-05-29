class TablesController < AccountsController
  include SearchAndFilterable

  def show
    @table = current_table
    @items = search_and_filter_items(item_scope)
    @property_value_options = property_value_options
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
      turbo_stream.replace("filter-input", partial: "filter_input", locals: { property: property })
    ]
  end

  helper_method :current_table
  def current_table
    @current_table ||= current_account.tables.friendly.find(params[:table_id] || params[:id])
  end

  private
  def item_scope
    current_table.items.order(:created_at)
  end

  def table_params
    params.require(:table).permit(:name, :import)
  end

  def property_value_options
    properties.select_type.map do |property|
      { property.id => property.all_values }
    end
  end
end
