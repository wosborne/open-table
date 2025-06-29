class CreateProduct < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
