class CreateProperty < ActiveRecord::Migration[8.0]
  def change
    create_table :properties do |t|
      t.references :table, null: false, foreign_key: true
      t.string :name, null: false, default: "Untitled"
      t.string :data_type, null: false
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
