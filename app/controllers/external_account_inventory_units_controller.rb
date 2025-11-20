class ExternalAccountInventoryUnitsController < InventoryUnitsController
  before_action :set_external_account_inventory_unit, only: [ :show, :update, :destroy ]
  before_action :set_ebay_account, only: [ :new, :create ]

  def show
    @inventory_unit = current_inventory_unit
    @external_account_inventory_unit = current_inventory_unit.ebay_listing_for_account(current_account)

    unless @external_account_inventory_unit
      redirect_to account_inventory_unit_path(current_account, current_inventory_unit),
                  alert: "No eBay listing found."
    end
  end

  def new
    @inventory_unit = current_inventory_unit
    @external_account_inventory_unit = ExternalAccountInventoryUnit.new
  end

  def create
    result = current_inventory_unit.add_to_ebay_inventory

    respond_to do |format|
      if result[:success]
        ebay_listing = result[:ebay_listing]
        format.html { redirect_to account_inventory_unit_external_account_inventory_unit_path(current_account, current_inventory_unit, ebay_listing), notice: "Successfully added to eBay inventory!" }
        format.turbo_stream { redirect_to account_inventory_unit_external_account_inventory_unit_path(current_account, current_inventory_unit, ebay_listing), notice: "Successfully added to eBay inventory!" }
      else
        @error = result[:message]
        @inventory_unit = current_inventory_unit
        @external_account_inventory_unit = ExternalAccountInventoryUnit.new

        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  def update
    @inventory_unit = current_inventory_unit
    action = params[:action_type]

    case action
    when "publish"
      result = current_inventory_unit.publish_ebay_offer
    when "end"
      result = @external_account_inventory_unit.end_listing
    else
      result = { success: false, message: "Unknown action: #{action}" }
    end

    if result[:success]
      # Reload the external_account_inventory_unit to get updated data
      @external_account_inventory_unit.reload
      render_response
    else
      @error = result[:message]
      render_response
    end
  end

  def destroy
    begin
      @external_account_inventory_unit.destroy
      redirect_to account_inventory_unit_path(current_account, current_inventory_unit),
                  notice: "eBay listing removed successfully!"
    rescue => e
      redirect_to account_inventory_unit_external_account_inventory_unit_path(current_account, current_inventory_unit, @external_account_inventory_unit),
                  alert: "Failed to remove from eBay: #{e.message}"
    end
  end

  private

  def set_ebay_account
    @ebay_account = current_account.external_accounts.find_by(service_name: "ebay")

    unless @ebay_account
      redirect_to account_inventory_unit_path(current_account, current_inventory_unit),
                  alert: "No eBay account connected to this account."
    end
  end

  def set_external_account_inventory_unit
    @external_account_inventory_unit = current_inventory_unit.ebay_listing_for_account(current_account)

    unless @external_account_inventory_unit
      @error = "No eBay listing found."
      render_response
      false
    end
  end

  def render_response
    respond_to do |format|
      format.turbo_stream
      format.html do
        if @error
          redirect_to account_inventory_unit_path(current_account, current_inventory_unit), alert: @error
        else
          redirect_to account_inventory_unit_path(current_account, current_inventory_unit)
        end
      end
    end
  end
end
