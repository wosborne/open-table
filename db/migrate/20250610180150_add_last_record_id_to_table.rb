class AddLastRecordIdToTable < ActiveRecord::Migration[8.0]
  def change
    add_column :tables, :last_record_id, :integer, default: 0
  end
end
