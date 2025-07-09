class AddAccountIdToTable < ActiveRecord::Migration[8.0]
  def change
    add_reference :tables, :account, null: false, foreign_key: true
  end
end
