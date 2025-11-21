class CreateConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :conditions do |t|
      t.string :name, null: false
      t.text :description
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conditions, [ :account_id, :name ], unique: true
  end
end
