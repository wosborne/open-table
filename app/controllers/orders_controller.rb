class OrdersController < AccountsController
  include SearchAndFilterable

  def index
    @orders = orders
  end

  def show
    @order = current_account.orders.includes(:order_line_items).find(params[:id])
  end

  private

  def orders
    @orders ||= search_and_filter_records(
      current_account.orders.includes(:order_line_items).order(created_at: :desc)
    )
  end
end
