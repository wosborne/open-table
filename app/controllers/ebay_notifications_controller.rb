class EbayNotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account

  def index
    @notifications = current_account.ebay_notifications
                                   .includes(:external_account, :inventory_unit, :order)
                                   .recent
                                   .page(params[:page])
                                   .per(20)

    @notification_types = EbayNotification.notification_types
    @statuses = EbayNotification.statuses

    # Apply filters
    if params[:notification_type].present?
      @notifications = @notifications.by_type(params[:notification_type])
    end

    if params[:status].present?
      @notifications = @notifications.where(status: params[:status])
    end

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @notifications = @notifications.where("raw_xml ILIKE ? OR ebay_item_id ILIKE ? OR ebay_transaction_id ILIKE ?", 
                                           search_term, search_term, search_term)
    end
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

  private

  def set_account
    @account = current_account
  end
end