class AddStateNonceToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :state_nonce, :string, null: true, default: nil
    add_index :users, :state_nonce, unique: true
  end
end
