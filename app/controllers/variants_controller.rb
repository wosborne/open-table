class VariantsController < AccountsController
  before_action :set_variant, only: [:show, :edit, :update, :destroy]

  def index
    @variants = current_account.variants.includes(:product, :product_option_values).order(created_at: :desc)
  end

  def show
  end

  def new
    @variant = current_account.variants.new
    @products = current_account.products.includes(:product_options, :product_option_values)
  end

  def create
    @variant = current_account.variants.new(variant_params)
    @products = current_account.products.includes(:product_options, :product_option_values)

    if @variant.save
      redirect_to account_variant_path(current_account, @variant), notice: "Variant was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = current_account.products.includes(:product_options, :product_option_values)
  end

  def update
    if @variant.update(variant_params)
      redirect_to account_variant_path(current_account, @variant), notice: "Variant was successfully updated."
    else
      @products = current_account.products.includes(:product_options, :product_option_values)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @variant.destroy
    redirect_to account_variants_path(current_account), notice: "Variant was successfully deleted."
  end

  def product_options
    @selected_product = current_account.products.find_by(id: params[:product_id])
    @ebay_aspects = nil
    
    # Fetch eBay aspects if product has category for new variant creation
    if @selected_product&.ebay_category_id.present?
      # Find an eBay external account to use for API calls
      ebay_account = current_account.external_accounts.where(service_name: 'ebay').first
      if ebay_account
        ebay_category = EbayCategory.new(ebay_account)
        aspects_data = ebay_category.format_item_specifics_for_form(@selected_product.ebay_category_id)
        @ebay_aspects = aspects_data[:variation_aspects] if aspects_data && !aspects_data[:error]
      end
    end
    
    render turbo_stream: turbo_stream.update("product_options", 
      partial: "product_options", 
      locals: { 
        selected_product: @selected_product,
        ebay_aspects: @ebay_aspects
      }
    )
  end

  private

  def set_variant
    @variant = current_account.variants.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:sku, :price, :product_id, product_option_values_attributes: [:product_option_id, :value, :_destroy])
  end

  def current_account
    @current_account ||= Account.find_by!(slug: params[:account_slug])
  end
end