class ModelTableComponent < ApplicationComponent
  def initialize(resources:, extra_columns: [], current_account: nil, model_class: nil)
    @resources = resources
    @extra_columns = extra_columns
    @current_account = current_account
    @klass = model_class || (resources.first.class if resources.any?)
  end

  private

  attr_reader :resources, :extra_columns, :current_account, :klass

  def all_columns
    base_columns = klass&.const_defined?(:TABLE_COLUMNS) ? klass::TABLE_COLUMNS : []
    base_columns + extra_columns
  end

  def column_value(resource, column)
    if extra_columns.include?(column)
      # Handle extra columns - assume they're aspect names
      resource.respond_to?(:aspect) ? resource.aspect(column) : resource.try(column)
    elsif column.to_s.ends_with?("_id")
      # Handle ID columns by looking for associated object name/title
      association_name = column.sub("_id", "")
      associated = resource.send(association_name)
      associated.try(:name) || associated.try(:title) || resource.send(column)
    else
      # Handle regular columns
      resource.send(column)
    end
  rescue
    # Fallback for any errors
    nil
  end

  def resource_url(resource)
    return "" unless current_account

    begin
      helpers.polymorphic_path([ current_account, resource ])
    rescue
      ""
    end
  end
end
