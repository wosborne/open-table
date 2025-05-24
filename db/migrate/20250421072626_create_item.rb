class CreateItem < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.references :table, null: false, foreign_key: true
      t.jsonb :properties, default: {}

      t.timestamps
    end

    add_index :items, :properties, using: :gin
  end
end
