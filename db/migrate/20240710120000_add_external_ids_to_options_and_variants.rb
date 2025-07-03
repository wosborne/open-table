class AddExternalIdsToOptionsAndVariants < ActiveRecord::Migration[7.0]
  def change
    add_column :product_options, :external_ids, :jsonb, default: {}, null: false
    add_column :product_option_values, :external_ids, :jsonb, default: {}, null: false
    add_column :variants, :external_ids, :jsonb, default: {}, null: false
  end
end
