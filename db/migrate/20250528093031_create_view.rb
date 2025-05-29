class CreateView < ActiveRecord::Migration[8.0]
  def change
    create_table :views do |t|
      t.string :name, null: false
      t.references :table, null: false, foreign_key: true
      t.string :slug, null: false

      t.timestamps
    end
    add_index :views, [ :name, :table_id ], unique: true
  end
end
