class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :state
      t.string :postcode
      t.string :country
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
