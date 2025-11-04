class EbayNotificationsController < AccountsController

  def index
    @notifications = current_account.ebay_notifications
                                   .includes(:external_account, :inventory_unit, :order)
                                   .recent
                                   .limit(50)

  end

  def destroy
    @notification = current_account.ebay_notifications.find(params[:id])
    @notification.destroy!
    redirect_to account_ebay_notifications_path(current_account), notice: 'Notification deleted successfully.'
  end

  def clear_all
    current_account.ebay_notifications.destroy_all
    redirect_to account_ebay_notifications_path(current_account), notice: 'All notifications cleared successfully.'
  end

end