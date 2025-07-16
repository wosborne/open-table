class OrdersController < AccountsController
  def index
    @orders = Order.includes(:order_line_items).order(created_at: :desc)
  end

  def show
    @order = Order.includes(:order_line_items).find(params[:id])
  end
end
