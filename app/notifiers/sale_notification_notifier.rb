# To deliver this notification:
#
# SaleNotificationNotifier.with(order: @order).deliver(@order.external_account.account)

class SaleNotificationNotifier < ApplicationNotifier
  # Real-time browser updates via ActionCable
  deliver_by :action_cable, channel: "NotificationsChannel" do |config|
    config.message = :message
  end

  # Required params
  required_param :order

  # Get the recipient account
  recipients do
    params[:order].external_account.account
  end

  # Notification data
  def message
    order = params[:order]
    amount = "#{order.currency} #{order.total_price}" if order.currency && order.total_price
    message = "You made a sale on #{order.external_account.service_name}"
    message += " for #{amount}" if amount
    message
  end

  def title
    "Sale"
  end

  def type
    "sale"
  end
end
