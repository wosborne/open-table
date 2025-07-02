class ExternalAccountProductsController < ProductsController
  # before_action :set_product, only: [ :edit, :update ]

  def create
    @external_account_product = current_product.external_account_products.new(external_account_product_params)

    if @external_account_product.save
      redirect_to account_product_path(current_account, current_product), notice: "Product was successfully added to #{@external_account_product.external_account.service_name.titleize}", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # if @product.update(product_params)
    #   redirect_to account_products_path(current_account), notice: "Product was successfully updated.", status: :see_other
    # else
    #   render :edit, status: :unprocessable_entity
    # end
  end

  private

  def external_account_product_params
    params.require(:external_account_product).permit(:external_account_id, :status)
  end

  # def set_product
  #   @product = current_account.products.find(params[:id])
  # end
end
