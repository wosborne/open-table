require "rails_helper"

RSpec.describe Product, type: :model do
  let(:account) { create(:account) }
  let(:product) { create(:product, name: "Test Product", account: account) }

  describe "#generate_variants_from_options" do
    context "with no options" do
      it "does not generate variants" do
        product.generate_variants_from_options
        expect(product.variants).to be_empty
      end
    end

    context "with single option" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }
      let!(:red_value) { create(:product_option_value, product_option: color_option, value: "Red") }
      let!(:blue_value) { create(:product_option_value, product_option: color_option, value: "Blue") }

      it "generates variants for each option value" do
        product.generate_variants_from_options
        
        # Variants are built in memory, not yet saved
        expect(product.variants.length).to eq(2)
        
        skus = product.variants.map(&:suggested_sku)
        expect(skus).to include("TESTPRODUCTRED")
        expect(skus).to include("TESTPRODUCTBLUE")
      end
    end

    context "with multiple options" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }
      let!(:size_option) { create(:product_option, product: product, name: "Size") }
      let!(:red_value) { create(:product_option_value, product_option: color_option, value: "Red") }
      let!(:blue_value) { create(:product_option_value, product_option: color_option, value: "Blue") }
      let!(:small_value) { create(:product_option_value, product_option: size_option, value: "Small") }
      let!(:large_value) { create(:product_option_value, product_option: size_option, value: "Large") }

      it "generates all combinations of option values" do
        product.generate_variants_from_options
        
        # Variants are built in memory, not yet saved
        expect(product.variants.length).to eq(4)  # 2 colors × 2 sizes
        
        skus = product.variants.map(&:suggested_sku)
        expect(skus).to include("TESTPRODUCTREDSMALL")
        expect(skus).to include("TESTPRODUCTREDLARGE") 
        expect(skus).to include("TESTPRODUCTBLUESMALL")
        expect(skus).to include("TESTPRODUCTBLUELARGE")
      end
    end

    context "with existing variants" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }
      let!(:red_value) { create(:product_option_value, product_option: color_option, value: "Red") }
      let!(:blue_value) { create(:product_option_value, product_option: color_option, value: "Blue") }

      it "does not create duplicate variants" do
        # Create initial variants and save them
        product.generate_variants_from_options
        product.variants.each { |v| v.sku = v.suggested_sku; v.price = 10.0 }
        product.save!
        expect(product.variants.count).to eq(2)
        
        # Add a new option value
        green_value = create(:product_option_value, product_option: color_option, value: "Green")
        product.reload  # Reload to get fresh associations
        
        # Generate variants again
        product.generate_variants_from_options
        
        expect(product.variants.length).to eq(3)  # Only one new variant created (in memory)
        expect(product.variants.map(&:suggested_sku)).to include("TESTPRODUCTGREEN")
      end
    end

    context "with empty option values" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }

      it "does not generate variants when option has no values" do
        product.generate_variants_from_options
        expect(product.variants).to be_empty
      end
    end
  end

  describe "#variants_affected_by_option_changes" do
    let(:product_with_variants) { create(:product_with_options, account: account) }

    context "when no option values change" do
      it "returns empty array" do
        affected = product_with_variants.variants_affected_by_option_changes
        expect(affected).to be_empty
      end
    end

    context "when option values change" do
      before do
        # Save variants with prices to make them persisted
        product_with_variants.variants.each_with_index do |variant, index|
          variant.update!(price: 100 + index * 10)
        end
      end

      it "detects variants affected by option value changes" do
        # Change an option value
        color_option = product_with_variants.product_options.find_by(name: "Color")
        red_value = color_option.product_option_values.find_by(value: "Red")
        red_value.update!(value: "Crimson")
        
        affected = product_with_variants.variants_affected_by_option_changes
        
        expect(affected).not_to be_empty
        expect(affected.first).to have_key(:variant)
        expect(affected.first).to have_key(:current_sku)
        expect(affected.first).to have_key(:suggested_sku)
      end

      it "returns variant info with current and suggested SKUs" do
        color_option = product_with_variants.product_options.find_by(name: "Color")
        red_value = color_option.product_option_values.find_by(value: "Red")
        
        # Get original SKU
        red_variants = product_with_variants.variants.select do |v|
          v.variant_option_values.any? { |vov| vov.product_option_value == red_value }
        end
        
        original_sku = red_variants.first.sku
        
        # Change option value
        red_value.update!(value: "Maroon")
        
        affected = product_with_variants.variants_affected_by_option_changes
        affected_variant_info = affected.first
        
        expect(affected_variant_info[:current_sku]).to eq(original_sku)
        expect(affected_variant_info[:suggested_sku]).to include("MAROON")
      end
    end

    context "with new (unpersisted) variants" do
      it "does not include unpersisted variants in affected list" do
        # Add new option values to generate new variants
        color_option = product_with_variants.product_options.find_by(name: "Color")
        create(:product_option_value, product_option: color_option, value: "Yellow")
        
        product_with_variants.generate_variants_from_options
        
        # Change option value
        red_value = color_option.product_option_values.find_by(value: "Red")
        red_value.update!(value: "Orange")
        
        affected = product_with_variants.variants_affected_by_option_changes
        
        # Should only include persisted variants
        affected.each do |variant_info|
          expect(variant_info[:variant]).to be_persisted
        end
      end
    end
  end

  describe "#all_variant_combinations" do
    context "with no options" do
      it "returns empty array" do
        expect(product.all_variant_combinations).to eq([])
      end
    end

    context "with options but no values" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }

      it "returns empty array" do
        expect(product.all_variant_combinations).to eq([])
      end
    end

    context "with complete options and values" do
      let!(:color_option) { create(:product_option, product: product, name: "Color") }
      let!(:size_option) { create(:product_option, product: product, name: "Size") }
      let!(:red_value) { create(:product_option_value, product_option: color_option, value: "Red") }
      let!(:blue_value) { create(:product_option_value, product_option: color_option, value: "Blue") }
      let!(:small_value) { create(:product_option_value, product_option: size_option, value: "Small") }
      let!(:large_value) { create(:product_option_value, product_option: size_option, value: "Large") }

      it "returns all possible combinations" do
        combinations = product.all_variant_combinations
        
        expect(combinations.length).to eq(4)
        
        # Each combination should be an array of ProductOptionValue objects
        combinations.each do |combination|
          expect(combination).to be_an(Array)
          expect(combination.length).to eq(2)  # 2 options
          expect(combination).to all(be_a(ProductOptionValue))
        end
      end

      it "generates correct combinations" do
        combinations = product.all_variant_combinations
        
        # Should include all 4 combinations (order doesn't matter)
        combination_values = combinations.map { |combo| combo.map(&:value).sort }
        
        expect(combination_values).to match_array([
          ["Blue", "Large"],
          ["Blue", "Small"], 
          ["Large", "Red"],
          ["Red", "Small"]
        ])
      end
    end
  end
end