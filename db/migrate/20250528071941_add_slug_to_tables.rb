class AddSlugToTables < ActiveRecord::Migration[8.0]
  def change
    add_column :tables, :slug, :string
    add_index :tables, :slug, unique: true
  end
end
