class EbayAspectsComponent < ApplicationComponent
  def initialize(product:)
    @product = product
  end

  private

  attr_reader :product

  def item_aspects
    @item_aspects ||= product.item_aspects
  end

  def variation_aspects
    @variation_aspects ||= product.variation_aspects
  end

  def brand_models_map
    @brand_models_map ||= product.brand_models_map
  end

  def saved_aspect_values
    @saved_aspect_values ||= product.saved_aspect_values
  end

  def aspect_value(aspect_name)
    saved_aspect_values[aspect_name]
  end

  def brand_select_options(aspect)
    [ [ "Select #{aspect[:name]}...", "" ] ] + aspect[:values].map { |v| [ v, v ] }
  end

  def model_select_options(aspect)
    saved_brand = aspect_value("Brand")
    available_models = saved_brand ? brand_models_map[saved_brand] || [] : []

    if available_models.any?
      [ [ "Select #{aspect[:name]}...", "" ] ] + available_models.map { |m| [ m, m ] }
    else
      [ [ "Select Brand first...", "" ] ]
    end
  end

  def model_field_disabled?
    saved_brand = aspect_value("Brand")
    available_models = saved_brand ? brand_models_map[saved_brand] || [] : []
    available_models.empty?
  end

  def regular_select_options(aspect)
    [ [ "Select #{aspect[:name]}...", "" ] ] + aspect[:values].map { |v| [ v, v ] }
  end
end
