class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.references :from_item, null: false, foreign_key: { to_table: :items }
      t.references :to_item, null: false, foreign_key: { to_table: :items }
      t.references :property, null: true, foreign_key: true
      t.timestamps
    end

    add_index :links, [ :from_item_id, :to_item_id ], unique: true
  end
end
