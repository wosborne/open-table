class AddTypeToProperty < ActiveRecord::Migration[8.0]
  def change
    add_column :properties, :type, :string

    Property.all.each do |property|
      case property.data_type
      when "text"
        property.update(type: "Properties::TextProperty")
      when "number"
        property.update(type: "Properties::NumberProperty")
      when "date"
        property.update(type: "Properties::DateProperty")
      when "select"
        property.update(type: "Properties::SelectProperty")
      when "checkbox"
        property.update(type: "Properties::CheckboxProperty")
      when "linked_record"
        property.update(type: "Properties::LinkedRecordProperty")
      when "formula"
        property.update(type: "Properties::FormulaProperty")
      end
    end
  end
end
