class ProductsController < AccountsController
  before_action :set_product, only: [ :show, :edit, :update, :regenerate_skus ]

  def index
    @products = current_account.products
    @extra_columns = gather_ebay_aspect_columns
  end

  def new
    @product = current_account.products.new
    load_ebay_categories
  end

  def create
    @product = current_account.products.new(product_params)

    if @product.save
      redirect_to edit_account_product_path(current_account, @product), notice: "Product was successfully created.", status: :see_other
    else
      load_ebay_categories
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    load_ebay_categories
  end

  def update
    if @product.update(product_params)
      redirect_to edit_account_product_path(current_account, @product), notice: "Product was successfully updated.", status: :see_other
    else
      load_ebay_categories
      render :edit, status: :unprocessable_entity
    end
  end

  def regenerate_skus
    affected_variants = @product.variants_affected_by_option_changes

    affected_variants.each do |variant_info|
      variant_info[:variant].regenerate_sku!
    end

    redirect_to edit_account_product_path(current_account, @product),
                notice: "#{affected_variants.count} variant SKUs were regenerated."
  end

  def ebay_category_aspects
    temp_product = Product.new(ebay_category_id: params[:category_id], account: current_account)
    @item_aspects = temp_product.item_aspects
    @variation_aspects = temp_product.variation_aspects
    @brand_models_map = temp_product.brand_models_map

    respond_to do |format|
      format.html { render partial: "products/form_options_dynamic", locals: {
        item_aspects: @item_aspects,
        variation_aspects: @variation_aspects,
        brand_models_map: @brand_models_map
      } }
    end
  end

  helper_method :current_product
  def current_product
    @current_product ||= current_account.products.find(params[:product_id] || params[:id])
  end

  private

  def gather_ebay_aspect_columns
    sql = <<~SQL
      SELECT DISTINCT jsonb_object_keys(ebay_aspects) as aspect_key
      FROM products 
      WHERE account_id = ? AND ebay_aspects IS NOT NULL AND ebay_aspects != '{}'
      ORDER BY aspect_key
    SQL
    
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, current_account.id])
    )
    result.map { |row| row['aspect_key'] }
  end

  def product_params
    params.require(:product).permit(:name, :description, :brand, :ebay_category_id, :ebay_category_name, ebay_aspects: {}, product_options_attributes: [ :id, :name, :_destroy ])
  end

  def set_product
    @product = current_product
  end

  def load_ebay_categories
    ebay_account = current_account.external_accounts.find_by(service_name: "ebay")
    if ebay_account.nil?
      @ebay_categories = []
      return
    end

    begin
      ebay_category = EbayCategory.new(ebay_account)
      mobile_categories = ebay_category.get_mobile_phone_categories

      if mobile_categories.is_a?(Array)
        @ebay_categories = mobile_categories.map do |suggestion|
          category_data = suggestion["category"]
          {
            category_id: category_data["categoryId"],
            display_name: category_data["categoryName"]
          }
        end
      else
        @ebay_categories = []
      end
    rescue => e
      Rails.logger.error "Failed to load eBay categories: #{e.message}"
      @ebay_categories = []
    end
  end
end
