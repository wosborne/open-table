class ViewPropertiesController < ViewsController
  def set_positions
    cleansed_position_ids.each_with_index do |id, index|
      current_view.view_properties.find_by(property_id: id).update(position: index)
    end

    redirect_to account_table_view_path(current_account, current_table, current_view)
  end

  def set_visibility
    current_view.view_properties.find(params[:id]).update(visible: params[:visible])

    redirect_to account_table_view_path(current_account, current_table, current_view)
  end

  private

  def visibility_params
    params.permit(:visible)
  end

  def cleansed_position_ids
    param_ids = params[:positions].split(",") || []
    param_ids.select! { |val| val.match?(/\A\d+\z/) }
    param_ids.map!(&:to_i)
    param_ids.uniq!
    param_ids.reject(&:zero?)
  end
end
