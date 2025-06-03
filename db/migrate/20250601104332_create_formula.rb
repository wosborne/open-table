class CreateFormula < ActiveRecord::Migration[8.0]
  def change
    create_table :formulas do |t|
      t.references :property, null: false, foreign_key: true
      t.jsonb :formula_data, default: {}

      t.timestamps
    end
  end
end
