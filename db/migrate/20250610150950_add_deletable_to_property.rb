class AddDeletableToProperty < ActiveRecord::Migration[8.0]
  def change
    add_column :properties, :deletable, :boolean, default: true
    add_column :properties, :editable, :boolean, default: true
  end
end
