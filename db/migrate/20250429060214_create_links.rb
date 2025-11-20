class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.references :from_record, null: false, foreign_key: { to_table: :records }
      t.references :to_record, null: false, foreign_key: { to_table: :records }
      t.references :property, null: true, foreign_key: true
      t.timestamps
    end
    add_index :links, [ :from_record_id, :to_record_id ], unique: true
  end
end
