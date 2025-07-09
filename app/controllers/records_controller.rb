class RecordsController < TablesController
  def create
    @record = current_table.records.create
  end

  def delete_records
    record_ids = params[:record_ids].split(",").reject(&:blank?)

    if record_ids.any? && current_table.records.where(id: record_ids).destroy_all
      render turbo_stream: record_ids.map { |id| turbo_stream.remove("record-#{id}") }
    end
  end

  def current_record
    @current_record ||= current_table.records.find(params[:record_id] || params[:id])
  end
end
