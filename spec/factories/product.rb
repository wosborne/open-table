FactoryBot.define do
  factory :product do
    name { "Test Product" }
    description { "A test product" }
    account { association :account }

    factory :product_with_options do
      after(:create) do |product|
        color_option = create(:product_option, product: product, name: "Color")
        size_option = create(:product_option, product: product, name: "Size")
        
        create(:product_option_value, product_option: color_option, value: "Red")
        create(:product_option_value, product_option: color_option, value: "Blue")
        create(:product_option_value, product_option: size_option, value: "Small")
        create(:product_option_value, product_option: size_option, value: "Large")
        
        product.generate_variants_from_options
        
        # Set SKUs and prices for generated variants
        product.variants.each_with_index do |variant, index|
          variant.sku = variant.suggested_sku if variant.sku.blank?
          variant.price = 100 + (index * 10)
        end
        
        product.save!
      end
    end

    factory :product_with_variants do
      after(:create) do |product|
        create_list(:variant, 3, product: product)
      end
    end
  end
end
