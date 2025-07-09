class Properties::IdProperty < Property
  after_create :create_ids_for_existing_values

  before_save :update_ids_with_prefix, if: :prefix_changed?

  def prefix_id(item_id)
    prefix.present? ? "#{prefix}-#{item_id}" : "#{item_id}"
  end

  private

  def create_ids_for_existing_values
    table.records.order(:created_at).each_with_index do |record, index|
      record.properties[id.to_s] = "#{index+1}"
      record.save
    end
  end

  def update_ids_with_prefix
    old_prefix = "#{prefix_was}-"
    table.records.each_with_index do |record|
      id_value = record.properties[id.to_s]&.gsub(old_prefix, "")
      record.properties[id.to_s] = "#{prefix}#{prefix.present? ? "-" : ""}#{id_value}"
      record.save
    end
  end
end
