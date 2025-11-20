class FulfillmentPoliciesController < ExternalAccountsController
  before_action :find_external_account
  before_action :set_fulfillment_policy, except: [ :new, :create, :shipping_services ]

  def new
    @fulfillment_policy = current_external_account.fulfillment_policies.build
  end

  def shipping_services
    begin
      ebay_client = EbayApiClient.new(current_external_account)
      @services = ebay_client.get_shipping_services
      @selected_service = params[:selected_service]
      render turbo_frame: "service-select"
    rescue => e
      Rails.logger.error "Error fetching eBay shipping services: #{e.message}"
      @services = []
      @selected_service = params[:selected_service]
      render turbo_frame: "service-select"
    end
  end

  def show
  end

  def edit
  end

  def create
    @fulfillment_policy = current_external_account.fulfillment_policies.build(
      fulfillment_policy_params.slice(:name, :marketplace_id)
    )
    @fulfillment_policy.ebay_policy_data = build_ebay_policy_data(fulfillment_policy_params)

    Rails.logger.info "Creating fulfillment policy with data: #{@fulfillment_policy.ebay_policy_data.to_json}"

    if @fulfillment_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Fulfillment policy '#{@fulfillment_policy.name}' created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @fulfillment_policy.assign_attributes(fulfillment_policy_params.slice(:name, :marketplace_id))
    @fulfillment_policy.ebay_policy_data = build_ebay_policy_data(fulfillment_policy_params)

    if @fulfillment_policy.save
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Fulfillment policy '#{@fulfillment_policy.name}' updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_name = @fulfillment_policy.name

    if @fulfillment_policy.destroy
      redirect_to account_external_account_path(current_account, current_external_account),
                  notice: "Fulfillment policy '#{policy_name}' deleted successfully!"
    else
      redirect_to account_external_account_fulfillment_policy_path(current_account, current_external_account, @fulfillment_policy),
                  alert: "Unable to delete fulfillment policy: #{@fulfillment_policy.errors.full_messages.join(', ')}"
    end
  end

  helper_method :current_fulfillment_policy
  def current_fulfillment_policy
    @fulfillment_policy
  end

  private

  def find_external_account
    @external_account = current_account.external_accounts.find(params[:external_account_id])
  end

  def set_fulfillment_policy
    @fulfillment_policy = current_external_account.fulfillment_policies.find(params[:id])
  end

  def fulfillment_policy_params
    params.require(:ebay_fulfillment_policy).permit(
      :name, :marketplace_id, :handling_time, :currency,
      :service_code, :cost, :free_shipping, :category_default
    )
  end


  def build_base_policy_data(params)
    {
      name: params[:name],
      marketplaceId: params[:marketplace_id] || "EBAY_GB"
    }
  end

  def build_ebay_policy_data(policy_params)
    policy_data = build_base_policy_data(policy_params).merge({
      categoryTypes: [
        {
          name: "ALL_EXCLUDING_MOTORS_VEHICLES",
          default: true
        }
      ],
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

      # Add carrier code if available
      carrier_code = get_shipping_carrier_for_service(policy_params[:service_code])
      if carrier_code.present?
        shipping_service[:shippingCarrierCode] = carrier_code
      elsif policy_params[:service_code]&.include?("DPD")
        shipping_service[:shippingCarrierCode] = "DPD"
      end

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

  def get_shipping_carrier_for_service(service_code)
    ebay_client = EbayApiClient.new(@external_account)
    shipping_services = ebay_client.get_shipping_services

    service = shipping_services.find { |s| s[:value] == service_code }
    service&.dig(:carrier)
  end
end
