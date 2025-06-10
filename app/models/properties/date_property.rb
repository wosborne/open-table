class Properties::DateProperty < Property
  before_save :convert_date_item_values, if: :format_changed?

  private

  def convert_date_item_values
    table.items.each do |item|
      value = item.properties[id.to_s]
      next unless value

      begin
        original_date = Date.strptime(value, format_was)
        new_date = original_date.strftime(format)
        item.properties[id.to_s] = new_date
        item.save
      rescue
        begin
          new_date = Date.strptime(value, format)
          item.properties[id.to_s] = new_date
          item.save
        rescue Date::Error => e
          next
        end
      rescue Date::Error => e
        next
      end
    end
  end
end
