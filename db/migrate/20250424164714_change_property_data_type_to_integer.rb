class ChangePropertyDataTypeToInteger < ActiveRecord::Migration[8.0]
  def change
    remove_column :properties, :data_type, :string

    add_column :properties, :data_type, :integer, default: 0, null: false
  end
end
