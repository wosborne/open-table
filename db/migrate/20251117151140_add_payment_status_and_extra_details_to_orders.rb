class AddPaymentStatusAndExtraDetailsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :payment_status, :string
    add_column :orders, :extra_details, :jsonb
  end
end
