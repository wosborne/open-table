class EbayController < AccountsController
  def opt_into_business_policies
    if ebay_policy_client
      result = ebay_policy_client.opt_into_business_policies
      
      if result[:success]
        redirect_to account_dashboard_path(current_account), notice: result[:message]
      else
        redirect_to account_dashboard_path(current_account), alert: result[:message]
      end
    else
      redirect_to account_dashboard_path(current_account), alert: "Please connect your eBay account first."
    end
  end

  private

  def ebay_policy_client
    return @ebay_policy_client if defined?(@ebay_policy_client)
    
    ebay_external_account = current_account.external_accounts.find_by(service_name: 'ebay')
    @ebay_policy_client = ebay_external_account ? EbayPolicyClient.new(ebay_external_account) : nil
  end
end