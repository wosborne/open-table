class InventoryUnitsController < AccountsController
  before_action :set_inventory_unit, only: [ :show, :edit, :update, :destroy, :delete_image_attachment ]

  def index
    @inventory_units = current_account.inventory_units.includes(:variant).order(created_at: :desc)
  end

  def show
  end

  def new
    @inventory_unit = current_account.inventory_units.new
    @products = current_account.products.includes(product_options: :product_option_values, variants: :variant_option_values)
  end

  def create
    @inventory_unit = current_account.inventory_units.new(inventory_unit_params)
    @products = current_account.products.includes(product_options: :product_option_values, variants: :variant_option_values)
    if @inventory_unit.save
      redirect_to account_inventory_units_path(current_account), notice: "Inventory unit created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = current_account.products.includes(product_options: :product_option_values, variants: :variant_option_values)
    if @inventory_unit.variant
      @selected_product = @inventory_unit.variant.product
      @selected_option_values = @inventory_unit.variant.variant_option_values.map(&:product_option_value_id)
      @variant = @inventory_unit.variant
    end
  end

  def update
    @products = current_account.products.includes(product_options: :product_option_values, variants: :variant_option_values)
    if @inventory_unit.update(inventory_unit_params)
      redirect_to account_inventory_unit_path(current_account, @inventory_unit)
    else
      if @inventory_unit.variant
        @selected_product = @inventory_unit.variant.product
        @selected_option_values = @inventory_unit.variant.variant_option_values.map(&:product_option_value_id)
        @variant = @inventory_unit.variant
      end
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inventory_unit.destroy
    redirect_to account_inventory_units_path(current_account), notice: "Inventory unit deleted."
  end

  def delete_image_attachment
    blob = ActiveStorage::Blob.find_signed(params[:signed_id])
    attachment = @inventory_unit.images.find { |img| img.blob == blob }
    attachment&.purge
    redirect_back(fallback_location: account_inventory_unit_path(current_account, @inventory_unit))
  end

  # Hotwire endpoint for dynamic variant selection
  def variant_selector
    @products = current_account.products.includes(product_options: :product_option_values, variants: :variant_option_values)
    @selected_product = current_account.products.find_by(id: params[:product_id])
    @selected_option_values = (params[:option_value_ids] || []).map(&:to_i)
    @variant = nil
    if @selected_product && @selected_option_values.present?
      @variant = @selected_product.variants.detect do |variant|
        variant.variant_option_values.map(&:product_option_value_id).sort == @selected_option_values.sort
      end
    end
    render partial: "product_option_selector", locals: { products: @products, selected_product: @selected_product, selected_option_values: @selected_option_values, variant: @variant }
  end


  def current_inventory_unit
    @current_inventory_unit ||= current_account.inventory_units.find(params[:inventory_unit_id] || params[:id])
  end
  helper_method :current_inventory_unit

  private

  def set_inventory_unit
    @inventory_unit = current_inventory_unit
  end

  def inventory_unit_params
    params.require(:inventory_unit).permit(:serial_number, :status, :variant_id, images: [])
  end
end
