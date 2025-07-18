class ExternalAccountsController < AccountsController
  skip_before_action :authenticate_user!, only: [ :shopify_callback ]
  skip_before_action :find_account, only: [ :shopify_callback ]

  def new
    @external_account = ExternalAccount.new
  end

  def create
    shopify_auth = ShopifyAuthentication.new

    if external_account_params[:service_name] == "shopify"
      auth_path = shopify_auth.authentication_path(current_user, external_account_params[:domain])

      redirect_to auth_path, allow_other_host: true
    else
      redirect_to new_account_external_account_path(current_account), alert: "Invalid service name"
    end
  end

  def shopify_callback
    shopify_auth = ShopifyAuthentication.new(params:)
    state = shopify_auth.decode_state(params["state"])
    user = User.find_by(id: state["user_id"], state_nonce: state["nonce"])

    if user
      shopify_auth.create_external_account_for(user)

      redirect_to account_tables_path(user.accounts.first), notice: "Shopify account connected successfully!"
    else
      redirect_to new_account_external_account_path(user.accounts.first), alert: "User not found"
    end
  end

  def destroy
    @external_account = current_account.external_accounts.find(params[:id])
    @external_account.destroy
    redirect_to edit_account_path(current_account), notice: "External account disconnected successfully!"
  end

  private

  def external_account_params
    params.require(:external_account).permit(:service_name, :domain)
  end
end
