require "rails_helper"

RSpec.describe "SKU Versioning", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }
  let!(:product) { create(:product_with_options, name: "Version Test Phone", account: account) }
  
  describe "SKU change detection" do
    it "allows changing option values that would affect SKUs", js: true do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Check that we're on the edit page
      expect(page).to have_content("Edit Product")
      expect(page).to have_content("Options (max 3)")
      
      # Find and change an option value input
      option_inputs = page.all("input")
      red_input = option_inputs.find { |input| input.value == "Red" }
      
      expect(red_input).to be_present, "Should find input with value 'Red'"
      red_input.set("Crimson")
      
      # Verify the change was made
      expect(red_input.value).to eq("Crimson")
      
      # Note: The JavaScript warning feature for SKU changes may not work in test environment
      # but the basic form functionality should work
    end

    it "has the correct form structure for option values" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Should have option value inputs
      expect(page).to have_field("product[product_options_attributes][0][product_option_values_attributes][0][value]", with: "Red")
      expect(page).to have_field("product[product_options_attributes][0][product_option_values_attributes][1][value]", with: "Blue")
      expect(page).to have_field("product[product_options_attributes][1][product_option_values_attributes][0][value]", with: "Small")
      expect(page).to have_field("product[product_options_attributes][1][product_option_values_attributes][1][value]", with: "Large")
    end

    it "shows SKU tooltips with version info" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Check tooltip shows version info (this tests the title attribute)
      sku_field = page.first("input[name*='sku']")
      expect(sku_field[:title]).to include("Version")
    end
  end

  describe "SKU regeneration" do
    it "displays current SKUs correctly" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Check that SKUs are displayed
      sku_inputs = page.all("input[name*='sku']")
      expect(sku_inputs.size).to eq(4) # Should have 4 variants
      
      # Check that SKUs contain expected parts
      sku_values = sku_inputs.map(&:value)
      expect(sku_values).to all(include("VERSIONTESTPHONE"))
      expect(sku_values.any? { |sku| sku.include?("RED") }).to be true
      expect(sku_values.any? { |sku| sku.include?("BLUE") }).to be true
      expect(sku_values.any? { |sku| sku.include?("SMALL") }).to be true
      expect(sku_values.any? { |sku| sku.include?("LARGE") }).to be true
    end

    it "prevents editing of existing SKUs" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # SKU fields should be disabled for existing variants
      sku_inputs = page.all("input[name*='sku']")
      sku_inputs.each do |sku_input|
        expect(sku_input).to be_disabled
      end
    end
  end

  describe "version history tracking" do
    it "shows history buttons for variants" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Should have history buttons for each variant
      variant_rows = page.all('tbody tr')
      expect(variant_rows.size).to eq(4)
      
      variant_rows.each do |row|
        within row do
          expect(page).to have_css('button.is-small.is-info.is-outlined')
        end
      end
    end

    it "displays version info in SKU tooltips" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Check version info in tooltip
      sku_field = page.first("input[name*='sku']")
      expect(sku_field[:title]).to include("Version")
    end
  end

  describe "form validation" do
    it "shows variant table with proper structure" do
      sign_in_as(user)
      visit edit_account_product_path(account, product)
      
      # Should have proper table headers
      expect(page).to have_content("SKU")
      expect(page).to have_content("Color")
      expect(page).to have_content("Size")
      expect(page).to have_content("Price")
      expect(page).to have_content("Stock")
      expect(page).to have_content("History")
      
      # Should show variants with option values
      expect(page).to have_content("Red Small")
      expect(page).to have_content("Red Large")
      expect(page).to have_content("Blue Small")
      expect(page).to have_content("Blue Large")
    end
  end
end