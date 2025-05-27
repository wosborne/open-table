class TablesController < AccountsController
  def show
    @table = current_table
    @items = search_and_filter_items
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
    @current_table ||= current_account.tables.find(params[:table_id] || params[:id])
  end

  private

  def table_params
    params.require(:table).permit(:name, :import)
  end

  def search_and_filter_items
    items = current_table.items.order(:created_at)
    items = filter_items(items) if params[:filters].present?
    items = search_items(items) if params[:search].present?

    items.limit(100)
  end

  def search_items(items)
    items.where(properties_query, search: "%#{params[:search]}%").limit(100)
  end

  def filter_items(items)
    JSON.parse(params[:filters])&.each do |property_id, value|
      pid = properties.find_by(id: property_id).id

      if pid && value.present?
        items = items.where("properties ->> ? ILIKE ?", pid.to_s, "%#{value}%")
      end
    end

    items
  end

  def properties_query
    properties.map do |property|
      "properties ->> '#{property.id}' ILIKE :search"
    end.join(" OR ")
  end

  def properties
    @properties ||= current_table.properties
  end

  def property_value_options
    properties.select_type.map do |property|
      { property.id => property.all_values }
    end
  end
end
