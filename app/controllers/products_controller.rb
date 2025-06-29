class ProductsController < AccountsController
  before_action :set_product, only: [ :edit, :update ]

  def index
    @products = current_account.products
  end

  def new
    @product = current_account.products.new
  end

  def create
    @product = current_account.products.new(product_params)

    if @product.save
      redirect_to account_products_path(current_account), notice: "Product was successfully created.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to account_products_path(current_account), notice: "Product was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def product_params
    params.require(:product).permit(:name, :description, variants_attributes: [ :id, :name, :price, :_destroy ])
  end

  def set_product
    @product = current_account.products.find(params[:id])
  end
end
