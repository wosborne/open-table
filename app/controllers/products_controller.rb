class ProductsController < AccountsController
  before_action :set_product, only: [ :edit, :update ]

  def index
    @products = current_account.products
  end

  def new
    @product = current_account.products.new
    3.times { @product.product_options.build } if @product.product_options.empty?
  end

  def create
    @product = current_account.products.new(product_params)

    if @product.save
      redirect_to edit_account_product_path(current_account, @product), notice: "Product was successfully created.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    (3 - @product.product_options.size).times { @product.product_options.build }
    build_all_variant_combinations
  end

  def update
    if @product.update(product_params)
      redirect_to edit_account_product_path(current_account, @product), notice: "Product was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  helper_method :current_product
  def current_product
    @current_product ||= current_account.products.find(params[:product_id] || params[:id])
  end

  private

  def product_params
    params.require(:product).permit(
      :name, :description,
      product_options_attributes: [
        :id, :name, :_destroy,
        product_option_values_attributes: [ :id, :value, :_destroy ]
      ],
      variants_attributes: [ :id, :price, :sku, :_destroy,
        variant_option_values_attributes: [ :id, :product_option_id, :product_option_value_id, :_destroy ]
      ]
    )
  end

  def set_product
    @product = current_account.products.find(params[:id])
  end

  # Build all possible variant combinations for display in the form
  def build_all_variant_combinations
    combos = @product.all_variant_combinations
    return if combos.empty?
    combos.each do |combination|
      combo_ids = combination.map(&:id).sort
      # Check if a variant (persisted or not) with this exact set of option values exists
      next if @product.variants.any? do |variant|
        vov_ids = variant.variant_option_values.map(&:product_option_value_id).compact.sort
        # Only consider a match if the variant has the full set of option values
        vov_ids.size == combo_ids.size && vov_ids == combo_ids
      end
      variant = @product.variants.build
      combination.each_with_index do |value, idx|
        variant.variant_option_values.build(
          product_option: @product.product_options[idx],
          product_option_value: value
        )
      end
    end
  end
end
