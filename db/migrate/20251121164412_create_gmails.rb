class CreateGmails < ActiveRecord::Migration[8.0]
  def change
    create_table :gmails do |t|
      t.references :account, null: false, foreign_key: true
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :email
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
