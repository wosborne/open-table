class AddAccountIdToTable < ActiveRecord::Migration[8.0]
  def change
    add_reference :tables, :account, null: false, foreign_key: true
    add_index :tables, :account_id
  end
end
