class CreatePropertyOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :property_options do |t|
      t.references :property, null: false, foreign_key: true
      t.string :value, null: false

      t.timestamps
    end
  end
end
