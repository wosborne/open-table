class RemoveNameFromVariants < ActiveRecord::Migration[8.0]
  def change
    remove_column :variants, :name, :string
  end
end
