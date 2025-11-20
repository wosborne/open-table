class CreateExternalAccount < ActiveRecord::Migration[8.0]
  def change
    create_table :external_accounts do |t|
      t.string :service_name, null: false
      t.string :api_token, null: false
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
