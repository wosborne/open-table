class Properties::DateProperty < Property
  before_save :convert_date_record_values, if: :format_changed?

  private

  def convert_date_record_values
    table.records.each do |record|
      value = record.properties[id.to_s]
      next unless value

      begin
        original_date = Date.strptime(value, format_was)
        new_date = original_date.strftime(format)
        record.properties[id.to_s] = new_date
        record.save
      rescue
        begin
          new_date = Date.strptime(value, format)
          record.properties[id.to_s] = new_date
          record.save
        rescue Date::Error => e
          next
        end
      rescue Date::Error => e
        next
      end
    end
  end
end
