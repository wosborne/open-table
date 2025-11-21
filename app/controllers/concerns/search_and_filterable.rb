module SearchAndFilterable
  def search_and_filter_records(scope)
    records = scope
    records = filter_records(records) if params[:filters].present?
    records = search_records(records) if params[:search].present?

    records.limit(100)
  end

  def search_records(records)
    model = records.model
    text_query = build_text_search_query(model)
    integer_query = build_integer_search_query(model)

    conditions = []
    conditions << records.where(text_query, search: "%#{params[:search]}%") if text_query.present?
    conditions << records.where(integer_query, search: params[:search].to_i) if integer_query.present? && numeric_search?

    conditions.reduce(:or) || records
  end

  def filter_records(records)
    JSON.parse(params[:filters])&.each do |attribute, value|
      valid_attribute = records.model::SEARCHABLE_ATTRIBUTES.find { |attr| attr == attribute }

      if valid_attribute && value.present?
        if integer_type?(records.model, valid_attribute)
          records = records.where("#{valid_attribute} = ?", value.to_i)
        else
          records = records.where("#{valid_attribute} ILIKE ?", "%#{value}%")
        end
      end
    end

    records
  end

  private

  def numeric_search?
    params[:search].match?(/^\d+$/)
  end

  def searchable_attributes_by_type(model)
    @searchable_attributes_by_type ||= {}
    @searchable_attributes_by_type[model] ||= {
      text: model::SEARCHABLE_ATTRIBUTES.select { |attr| text_type?(model, attr) },
      integer: model::SEARCHABLE_ATTRIBUTES.select { |attr| integer_type?(model, attr) }
    }
  end

  def text_type?(model, attribute)
    [ :string, :text ].include?(attribute_type(model, attribute))
  end

  def integer_type?(model, attribute)
    [ :integer, :bigint ].include?(attribute_type(model, attribute))
  end

  def attribute_type(model, attribute_name)
    column = model.columns_hash[attribute_name.to_s]
    column&.type
  end

  def build_text_search_query(model)
    text_attrs = searchable_attributes_by_type(model)[:text]
    return "" if text_attrs.empty?
    text_attrs.map { |attr| "#{attr} ILIKE :search" }.join(" OR ")
  end

  def build_integer_search_query(model)
    int_attrs = searchable_attributes_by_type(model)[:integer]
    return "" if int_attrs.empty?
    int_attrs.map { |attr| "#{attr} = :search" }.join(" OR ")
  end
end
