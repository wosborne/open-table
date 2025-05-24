class AddLinkedTableToProperty < ActiveRecord::Migration[8.0]
  def change
    add_reference :properties, :linked_table, foreign_key: { to_table: :tables }
  end
end
