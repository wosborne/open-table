class CreateProductOptionsAndValues < ActiveRecord::Migration[8.0]
  def change
    create_table :product_options do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :product_option_values do |t|
      t.references :product_option, null: false, foreign_key: true
      t.string :value, null: false
      t.timestamps
    end

    create_table :variant_option_values do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :product_option, null: false, foreign_key: true
      t.references :product_option_value, null: false, foreign_key: true
      t.timestamps
    end

    change_table :variants do |t|
      t.index :sku, unique: true
    end
  end
end
