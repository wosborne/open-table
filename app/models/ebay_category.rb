class EbayCategory
  attr_reader :external_account, :api_client

  def initialize(external_account)
    @external_account = external_account
    @api_client = EbayApiClient.new(external_account)
  end

  def get_categories
    result = @api_client.get("/commerce/taxonomy/v1/category_tree/0", { marketplace_id: "EBAY_GB" })
    
    if result[:success]
      result[:data]
    else
      { error: result[:error] }
    end
  end

  def get_category_tree(category_id = nil)
    endpoint = if category_id
      "/commerce/taxonomy/v1/category_tree/0/get_category_subtree"
    else
      "/commerce/taxonomy/v1/category_tree/0"
    end
    
    params = { marketplace_id: "EBAY_GB" }
    params[:category_id] = category_id if category_id

    result = @api_client.get(endpoint, params)
    
    if result[:success]
      result[:data]
    else
      { error: result[:error] }
    end
  end

  def get_item_specifics(category_id)
    result = @api_client.get("/commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category", {
      marketplace_id: "EBAY_GB",
      category_id: category_id
    })
    
    if result[:success]
      result[:data]
    else
      { error: result[:error] }
    end
  end

  def search_categories(query)
    result = @api_client.get("/commerce/taxonomy/v1/category_tree/0/get_category_suggestions", {
      marketplace_id: "EBAY_GB", 
      q: query
    })
    
    if result[:success]
      result[:data]
    else
      { error: result[:error] }
    end
  end

  def get_category_details(category_id)
    result = @api_client.get("/commerce/taxonomy/v1/category_tree/0/get_category_subtree", {
      marketplace_id: "EBAY_GB",
      category_id: category_id
    })
    
    if result[:success]
      category_data = result[:data]
      
      specifics_result = get_item_specifics(category_id)
      
      {
        category: category_data,
        item_specifics: specifics_result[:error] ? [] : specifics_result[:aspects] || []
      }
    else
      { error: result[:error] }
    end
  end

  def get_mobile_phone_categories
    search_result = search_categories("mobile phone")
    
    if search_result[:error]
      return { error: search_result[:error] }
    end

    categories = search_result["categorySuggestions"] || []
    
    mobile_categories = categories.select do |suggestion|
      category_data = suggestion["category"]
      name = category_data["categoryName"] || suggestion["categoryTreeNodeAncestors"]&.last&.dig("categoryName") || ""
      name.downcase.include?("phone") || name.downcase.include?("smartphone") || name.downcase.include?("cell")
    end
    
    mobile_categories
  end

  def format_item_specifics_for_form(category_id)
    specifics = get_item_specifics(category_id)
    
    return { item_aspects: [], variation_aspects: [] } if specifics["error"] || specifics[:error]
    
    aspects = specifics["aspects"] || []
    
    # Filter to only required aspects
    required_aspects = aspects.select do |aspect|
      aspect.dig("aspectConstraint", "aspectRequired") == true
    end
    
    # Separate into item-level and variation-level aspects
    item_aspects = []
    variation_aspects = []
    
    required_aspects.each do |aspect|
      aspect_data = {
        name: aspect["localizedAspectName"],
        required: true,
        values: aspect["aspectValues"]&.map { |v| v["localizedValue"] } || [],
        input_type: determine_input_type(aspect),
        data_type: aspect.dig("aspectConstraint", "aspectDataType"),
        cardinality: aspect.dig("aspectConstraint", "itemToAspectCardinality"),
        mode: aspect.dig("aspectConstraint", "aspectMode")
      }
      
      # Check if this aspect can be used for variations
      enabled_for_variations = aspect.dig("aspectConstraint", "aspectEnabledForVariations") == true
      
      # Override: Model should always be item-level (one model per product)
      if aspect_data[:name].downcase == "model"
        Rails.logger.info "Aspect '#{aspect_data[:name]}' - forcing to item-level (override eBay's variation setting)"
        item_aspects << aspect_data
      elsif enabled_for_variations
        Rails.logger.info "Aspect '#{aspect_data[:name]}' - variation-level"
        variation_aspects << aspect_data
      else
        Rails.logger.info "Aspect '#{aspect_data[:name]}' - item-level"
        item_aspects << aspect_data
      end
    end
    
    # Process brand-model relationships for cascading selects
    brand_models_map = build_brand_models_mapping(required_aspects)
    
    {
      item_aspects: item_aspects,
      variation_aspects: variation_aspects,
      brand_models_map: brand_models_map
    }
  end

  private

  def build_brand_models_mapping(aspects)
    brand_aspect = aspects.find { |a| a["localizedAspectName"]&.downcase == "brand" }
    model_aspect = aspects.find { |a| a["localizedAspectName"]&.downcase == "model" }
    
    return {} unless brand_aspect && model_aspect
    
    brands = brand_aspect["aspectValues"]&.map { |v| v["localizedValue"] } || []
    models = model_aspect["aspectValues"]&.map { |v| v["localizedValue"] } || []
    
    # Filter models by brand name - eBay includes brand name in model names
    brand_models = {}
    
    brands.each do |brand|
      brand_models[brand] = models.select { |model| 
        model.downcase.include?(brand.downcase) 
      }
    end
    
    brand_models
  end

  def determine_input_type(aspect)
    values_count = aspect["aspectValues"]&.length || 0
    
    if values_count == 0
      "text"
    elsif values_count <= 50
      "select"
    else
      "autocomplete"
    end
  end
end