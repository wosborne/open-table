class ConditionsController < AccountsController
  before_action :set_condition, only: [ :show, :edit, :update, :destroy ]

  def index
    @conditions = current_account.conditions.order(:name)
  end

  def show
  end

  def new
    @condition = current_account.conditions.build
  end

  def edit
  end

  def create
    @condition = current_account.conditions.build(condition_params)

    if @condition.save
      redirect_to [ current_account, @condition ], notice: "Condition was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @condition.update(condition_params)
      redirect_to [ current_account, @condition ], notice: "Condition was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @condition.destroy
    redirect_to account_conditions_url(current_account), notice: "Condition was successfully deleted."
  end

  private

  def set_condition
    @condition = current_account.conditions.find(params[:id])
  end

  def condition_params
    params.require(:condition).permit(:name, :description, :ebay_condition)
  end
end
