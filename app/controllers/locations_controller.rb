class LocationsController < AccountsController
  before_action :set_location, only: [:show, :edit, :update, :destroy]

  def index
    @locations = current_account.locations
  end

  def show
  end

  def new
    @location = current_account.locations.new
  end

  def create
    @location = current_account.locations.new(location_params)

    if @location.save
      ebay_account = current_account.external_accounts.find_by(service_name: 'ebay')
      if ebay_account
        redirect_to account_external_account_path(current_account, ebay_account), notice: 'Location was successfully created and synced to eBay.'
      else
        redirect_to account_location_path(current_account, @location), notice: 'Location was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to account_location_path(current_account, @location), notice: 'Location was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    redirect_to account_locations_path(current_account), notice: 'Location was successfully deleted.'
  end

  private

  def set_location
    @location = current_account.locations.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :address_line_1, :address_line_2, :city, :state, :postcode, :country)
  end
end
