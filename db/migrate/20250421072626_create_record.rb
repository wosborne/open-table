class CreateRecord < ActiveRecord::Migration[8.0]
  def change
    create_table :records do |t|
      t.references :table, null: false, foreign_key: true
      t.jsonb :properties, default: {}
      t.timestamps
    end
    add_index :records, :properties, using: :gin
  end
end
