class FulfillmentPoliciesController < ExternalAccountsController
  include EbayPolicyManageable

  def new
    @fulfillment_policy = build_policy_model({}, "fulfillment")
  end

  def shipping_services
    begin
      ebay_client = EbayApiClient.new(@external_account)
      @services = ebay_client.get_shipping_services
      render turbo_frame: "service-select"
    rescue => e
      Rails.logger.error "Error fetching eBay shipping services: #{e.message}"
      @services = []
      render turbo_frame: "service-select"
    end
  end

  def create
    form_params = fulfillment_policy_params
    @fulfillment_policy = build_policy_model(form_params, "fulfillment")

    policy_data = build_ebay_policy_data(form_params)
    create_policy_via_ebay_api(@fulfillment_policy, policy_data, :create_fulfillment_policy, "fulfillmentPolicyId")
  end

  private

  def fulfillment_policy_params
    params.require(:fulfillment_policy).permit(
      :name, :marketplace_id, :handling_time, :currency,
      :service_code, :cost, :free_shipping
    )
  end

  def build_ebay_policy_data(policy_params)
    policy_data = build_base_policy_data(policy_params).merge({
      handlingTime: {
        value: policy_params[:handling_time].to_i,
        unit: "DAY"
      },
      localPickup: false,
      shipToLocations: {
        regionIncluded: [
          {
            regionType: "COUNTRY",
            regionId: "GB"
          }
        ]
      },
      shippingOptions: []
    })

    # Add shipping option if provided
    if policy_params[:service_code].present?
      shipping_service = {
        shippingServiceCode: policy_params[:service_code],
        freeShipping: policy_params[:free_shipping] == "1"
      }

      unless policy_params[:free_shipping] == "1"
        if policy_params[:cost].present?
          shipping_service[:shippingCost] = {
            value: policy_params[:cost].to_s,
            currency: policy_params[:currency] || "GBP"
          }
        end
      end

      shipping_option = {
        optionType: "DOMESTIC",
        costType: "FLAT_RATE",
        shippingServices: [ shipping_service ]
      }

      policy_data[:shippingOptions] << shipping_option
    end

    policy_data
  end
end
