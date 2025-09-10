class ExternalAccountInventoryUnitsController < InventoryUnitsController
  before_action :set_external_account_inventory_unit, only: [:destroy]

  def create
    ebay_account = current_account.external_accounts.find_by(service_name: 'ebay')
    
    unless ebay_account
      @error = "No eBay account connected to this account."
      return render_response
    end

    @external_account_inventory_unit = current_inventory_unit.external_account_inventory_units.build(
      external_account: ebay_account,
      marketplace_data: { status: 'draft' }
    )

    if @external_account_inventory_unit.save
      render_response
    else
      @error = "Failed to create eBay listing."
      render_response
    end
  end

  def destroy
    if @external_account_inventory_unit.destroy
      render_response
    else
      @error = "Failed to delete eBay listing."
      render_response
    end
  end

  private

  def set_external_account_inventory_unit
    @external_account_inventory_unit = current_inventory_unit.ebay_listing_for_account(current_account)
    
    unless @external_account_inventory_unit
      @error = "No eBay listing found."
      render_response
      return false
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