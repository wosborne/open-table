class CreateExternalAccountProduct < ActiveRecord::Migration[8.0]
  def change
    create_table :external_account_products do |t|
      t.references :external_account, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :external_id
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
