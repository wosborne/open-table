class EbayApiResponse
  attr_reader :success, :status_code, :data, :error, :detailed_errors

  def initialize(success:, status_code:, data: nil, error: nil, detailed_errors: [])
    @success = success
    @status_code = status_code
    @data = data
    @error = error
    @detailed_errors = detailed_errors
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def code
    @status_code
  end

  def body
    @data&.to_json
  end

  def error_messages
    return [] if @detailed_errors.empty?
    
    @detailed_errors.map do |error|
      error[:long_message] || error[:message] || "Unknown error"
    end
  end

  def inspect
    "#<EbayApiResponse success=#{@success} code=#{@status_code} data_keys=#{@data&.keys}>"
  end
end