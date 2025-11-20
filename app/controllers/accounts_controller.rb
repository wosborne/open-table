class AccountsController < ApplicationController
  layout :set_layout

  before_action :find_account, except: [ :new, :create, :edit, :update, :show ]

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      current_user.account_users.create(account: @account)
      redirect_to account_dashboard_path(@account), notice: "Account created successfully."
    else
      render :new
    end
  end

  def edit
    @account = current_account
  end

  def update
    @account = current_account

    if @account.update(account_params)
      redirect_to account_products_path(account_slug: @account.slug), notice: "Account updated successfully."
    else
      render :edit
    end
  end

  def show
    @account = current_account
  end

  helper_method :current_account
  def current_account
    @current_account ||= current_user.accounts.find_by(slug: params[:account_slug]) || current_user.accounts.first
  end

  private

  def account_params
    params.require(:account).permit(:name, :slug)
  end

  def find_account
    if current_user && !current_account
      redirect_to new_account_path
    elsif current_user && current_account && !params[:account_slug]
      redirect_to account_products_path(current_account)
    elsif current_user && current_account && params[:account_slug] != current_account.slug
      redirect_to account_products_path(current_account)
    end
  end

  def set_layout
    case self.class.name
    when "AccountsController", "ExternalAccountsController", "LocationsController"
      "accounts"
    else
      "dashboard"
    end
  end
end
