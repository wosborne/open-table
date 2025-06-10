class Properties::IdProperty < Property
  after_create :create_ids_for_existing_values

  before_save :update_ids_with_prefix, if: :prefix_changed?

  private

  def create_ids_for_existing_values
    table.items.order(:created_at).each_with_index do |item, index|
      item.properties[id.to_s] = "#{index+1}"
      item.save
    end
  end

  def update_ids_with_prefix
    old_prefix = "#{prefix_was}-"
    table.items.each_with_index do |item|
      id_value = item.properties[id.to_s].gsub(old_prefix, "")
      item.properties[id.to_s] = "#{prefix}#{prefix.present? ? "-" : ""}#{id_value}"
      item.save
    end
  end
end
