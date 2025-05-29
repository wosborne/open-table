module SearchAndFilterable
  def search_and_filter_items(scope)
    items = scope
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
end
