require "rails_helper"

RSpec.describe Variant, type: :model do
  let(:account) { create(:account) }
  let(:product) { create(:product, account: account) }
  let(:variant) { create(:variant, product: product, sku: "ORIGINAL-SKU") }

  describe "PaperTrail integration" do
    it "creates version when SKU changes via regenerate" do
      expect { variant.regenerate_sku! }.to change { variant.versions.count }.by(1)
    end

    it "creates version when price changes" do
      expect { variant.update!(price: 99.99) }.to change { variant.versions.count }.by(1)
    end

    it "does not create version for other attributes" do
      # external_ids is not tracked
      expect { variant.update!(external_ids: { "test" => "value" }) }.not_to change { variant.versions.count }
    end
  end

  describe "#sku_version_number" do
    it "returns correct count including creation version" do
      # PaperTrail creates a version on creation, so count starts at 1
      expect(variant.sku_version_number).to be >= 1
    end

    it "returns incremented count based on versions" do
      initial_count = variant.versions.count
      variant.regenerate_sku! # Use regenerate_sku! to bypass protection
      variant.reload
      
      expect(variant.sku_version_number).to eq(initial_count + 2) # +1 for creation, +1 for regenerate
    end
  end

  describe "#previous_sku" do
    it "returns nil for variant with only creation version" do
      # If variant only has the creation version, no previous SKU exists
      expect(variant.previous_sku).to be_nil
    end

    it "returns previous SKU after change" do
      original_sku = variant.sku
      variant.regenerate_sku! # Use regenerate to bypass protection
      
      expect(variant.previous_sku).to eq(original_sku)
    end

    it "returns most recent previous SKU" do
      original_sku = variant.sku
      variant.regenerate_sku!
      
      # After one change, previous_sku should return the original SKU
      expect(variant.previous_sku).to eq(original_sku)
    end
  end

  describe "#regenerate_sku!" do
    let(:color_option) { create(:product_option, product: product, name: "Color") }
    let(:color_value) { create(:product_option_value, product_option: color_option, value: "Red") }
    
    before do
      create(:variant_option_value, variant: variant, product_option: color_option, product_option_value: color_value)
      # Set a manual SKU using regenerate to bypass protection initially
      variant.instance_variable_set(:@allow_sku_change, true)
      variant.update!(sku: "MANUAL-SKU")
      variant.instance_variable_set(:@allow_sku_change, false)
    end

    it "updates SKU to suggested value" do
      expect { variant.regenerate_sku! }.to change { variant.sku }.to(variant.suggested_sku)
    end

    it "bypasses SKU change prevention" do
      # Normally SKU changes are prevented for persisted variants
      expect { variant.regenerate_sku! }.not_to raise_error
    end

    it "creates a version when regenerating" do
      expect { variant.regenerate_sku! }.to change { variant.versions.count }.by(1)
    end
  end

  describe "#suggested_sku" do
    let(:product) { create(:product, name: "Smart Phone", account: account) }
    let(:color_option) { create(:product_option, product: product, name: "Color") }
    let(:size_option) { create(:product_option, product: product, name: "Size") }
    let(:red_value) { create(:product_option_value, product_option: color_option, value: "Red") }
    let(:large_value) { create(:product_option_value, product_option: size_option, value: "64GB") }
    
    before do
      create(:variant_option_value, variant: variant, product_option: color_option, product_option_value: red_value)
      create(:variant_option_value, variant: variant, product_option: size_option, product_option_value: large_value)
    end

    it "generates SKU from product name and option values" do
      expect(variant.suggested_sku).to eq("SMARTPHONERED64GB")
    end

    it "removes spaces and converts to uppercase" do
      product.update!(name: "My Test Product")
      red_value.update!(value: "bright red")
      
      expect(variant.suggested_sku).to eq("MYTESTPRODUCTBRIGHTRED64GB")
    end

    it "handles missing option values gracefully" do
      # Create variant with incomplete option values
      variant_without_size = create(:variant, product: product)
      create(:variant_option_value, variant: variant_without_size, product_option: color_option, product_option_value: red_value)
      
      expect(variant_without_size.suggested_sku).to eq("SMARTPHONERED")
    end
  end

  describe "#sku_history" do
    it "returns history including creation version" do
      history = variant.sku_history
      expect(history).to be_an(Array)
      expect(history.length).to be >= 1  # At least creation version
    end

    it "returns history of SKU changes" do
      variant.regenerate_sku!
      variant.regenerate_sku!
      
      history = variant.sku_history
      expect(history).to be_an(Array)
      expect(history.length).to be >= 2  # Multiple versions created
      
      # Check structure of history entries
      history.each do |entry|
        expect(entry).to have_key(:version)
        expect(entry).to have_key(:changed_at)
        expect(entry).to have_key(:version_number)
      end
    end
  end

  describe "SKU validation and constraints" do
    it "prevents manual SKU changes on persisted variants" do
      persisted_variant = create(:variant, sku: "LOCKED-SKU")
      
      # Attempt to change SKU should fail
      result = persisted_variant.update(sku: "CHANGED-SKU")
      expect(result).to be_falsey
      expect(persisted_variant.errors[:sku]).to include("cannot be changed after save")
    end

    it "allows SKU changes on new variants" do
      new_variant = build(:variant, sku: "NEW-SKU")
      
      expect { new_variant.save! }.not_to raise_error
      expect(new_variant.sku).to eq("NEW-SKU")
    end

    it "enforces SKU uniqueness within product scope" do
      variant1 = create(:variant, product: product, sku: "UNIQUE-SKU")
      variant2 = build(:variant, product: product, sku: "UNIQUE-SKU")
      
      expect(variant2).not_to be_valid
      expect(variant2.errors[:sku]).to include("has already been taken")
    end
  end
end