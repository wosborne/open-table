class CreateFilter < ActiveRecord::Migration[8.0]
  def change
    create_table :filters do |t|
      t.references :view, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.string :value, null: false

      t.timestamps
    end

    add_index :filters, [ :view_id, :property_id ]
  end
end
