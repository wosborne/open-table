class Properties::UpdateProperty < ApplicationService
  def initialize(property, params)
    @property = property
    @params = params
    map_type_param
  end

  def call
    @property.assign_attributes(@params)
    @property = @property.recast
    @property.update(@params)
    @property
  end

  private

  def map_type_param
    @params[:type] = Property::TYPE_MAP[@params[:type]] if @params[:type].present?
  end
end
