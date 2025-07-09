module SearchAndFilterable
  def search_and_filter_records(scope)
    records = scope
    records = filter_records(records) if params[:filters].present?
    records = search_records(records) if params[:search].present?

    records.limit(100)
  end

  def search_records(records)
    records.where(properties_query, search: "%#{params[:search]}%").limit(100)
  end

  def filter_records(records)
    JSON.parse(params[:filters])&.each do |property_id, value|
      pid = properties.find_by(id: property_id).id

      if pid && value.present?
        records = records.where("properties ->> ? ILIKE ?", pid.to_s, "%#{value}%")
      end
    end

    records
  end

  def properties_query
    properties.searchable.map do |property|
      "properties ->> '#{property.id}' ILIKE :search"
    end.join(" OR ")
  end

  def properties
    @properties ||= current_table.properties
  end
end
