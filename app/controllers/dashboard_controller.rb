class DashboardController < AccountsController
  def index
    @onboarding_status = calculate_onboarding_status
    @has_products = current_account.products.any?
    @has_variants = current_account.variants.any?
    @has_inventory_units = current_account.inventory_units.any?
  end

  private

  def calculate_onboarding_status
    steps = [
      {
        name: "eBay Account Connected",
        description: "Connect your eBay account to start selling",
        completed: ebay_account_connected?
      },
      {
        name: "Business Policies Opt-in",
        description: "Opt into eBay's Business Policies Management program",
        completed: business_policies_opted_in?
      },
      {
        name: "Inventory Location",
        description: "Set up your inventory location for eBay shipping",
        completed: inventory_location_configured?
      },
      {
        name: "Payment Policy",
        description: "Create a payment policy for accepting payments",
        completed: policy_exists?(:payment)
      },
      {
        name: "Fulfillment Policy",
        description: "Create a fulfillment policy for shipping options",
        completed: policy_exists?(:fulfillment)
      },
      {
        name: "Return Policy", 
        description: "Create a return policy for customer returns",
        completed: policy_exists?(:return)
      }
    ]

    completed_steps = steps.count { |step| step[:completed] }
    
    {
      steps: steps,
      completion_percentage: (completed_steps.to_f / steps.length * 100).round,
      is_complete: completed_steps == steps.length
    }
  end

  def ebay_account_connected?
    current_account.external_accounts.where(service_name: 'ebay').exists?
  end

  def business_policies_opted_in?
    return false unless ebay_policy_client
    
    begin
      ebay_policy_client.is_opted_into_business_policies?
    rescue
      false
    end
  end

  def inventory_location_configured?
    ebay_account = current_account.external_accounts.find_by(service_name: 'ebay')
    return false unless ebay_account
    
    # Check if any locations are synced to eBay
    current_account.locations.any?(&:synced_to_ebay?)
  end

  def policy_exists?(policy_type)
    return false unless ebay_policy_client
    
    begin
      case policy_type
      when :fulfillment
        ebay_policy_client.get_fulfillment_policies.any?
      when :payment
        ebay_policy_client.get_payment_policies.any?
      when :return
        ebay_policy_client.get_return_policies.any?
      else
        false
      end
    rescue
      false
    end
  end

  def ebay_policy_client
    return @ebay_policy_client if defined?(@ebay_policy_client)
    
    ebay_external_account = current_account.external_accounts.find_by(service_name: 'ebay')
    @ebay_policy_client = ebay_external_account ? EbayPolicyClient.new(ebay_external_account) : nil
  end
end