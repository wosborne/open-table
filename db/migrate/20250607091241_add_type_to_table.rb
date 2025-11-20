class AddTypeToTable < ActiveRecord::Migration[8.0]
  def change
    add_column :tables, :type, :string
  end
end
