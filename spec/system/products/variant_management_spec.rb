require "rails_helper"

RSpec.describe "Variant Management", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }

  describe "variant generation" do
    it "automatically generates variants when options are added" do
      sign_in_as(user)
      visit new_account_product_path(account)
      
      fill_in "product[name]", with: "Test Phone"
      fill_in "product[description]", with: "A test phone"
      
      # Add Color option with values
      fill_in "product[product_options_attributes][0][name]", with: "Color"
      all("button", text: "Add Value").first.click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("Red") if empty_input
      all("button", text: "Add Value").first.click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("Blue") if empty_input
      
      # Add Size option with values  
      fill_in "product[product_options_attributes][1][name]", with: "Size"
      all("button", text: "Add Value")[1].click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("64GB") if empty_input
      all("button", text: "Add Value")[1].click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("128GB") if empty_input
      
      click_button "Create Product"
      
      expect(page).to have_content("Product was successfully created")
      
      # Should generate 4 variants (2 colors × 2 sizes)
      expect(page).to have_content("Red")
      expect(page).to have_content("Blue") 
      expect(page).to have_content("64GB")
      expect(page).to have_content("128GB")
      
      # Check that variants table has correct number of rows
      variant_rows = page.all("tbody tr")
      expect(variant_rows.count).to eq(4)
    end

    it "generates SKUs automatically for new variants" do
      sign_in_as(user)
      visit new_account_product_path(account)
      
      fill_in "product[name]", with: "SmartPhone"
      fill_in "product[product_options_attributes][0][name]", with: "Color"
      all("button", text: "Add Value").first.click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("Black") if empty_input
      
      click_button "Create Product"
      
      expect(page).to have_content("Product was successfully created")
      
      # Check that SKU is auto-generated
      expect(page).to have_field("product[variants_attributes][0][sku]", with: /SMARTPHONEBLACK/i)
    end

    it "shows correct option values for each variant" do
      sign_in_as(user)
      product = create(:product_with_options, name: "Test Product", account: account)
      
      visit edit_account_product_path(account, product)
      
      # Check that each variant displays correct option combinations
      variant_rows = page.all("tbody tr")
      
      expect(variant_rows[0]).to have_content("Red") 
      expect(variant_rows[0]).to have_content("Small")
      
      expect(variant_rows[1]).to have_content("Red")
      expect(variant_rows[1]).to have_content("Large") 
      
      expect(variant_rows[2]).to have_content("Blue")
      expect(variant_rows[2]).to have_content("Small")
      
      expect(variant_rows[3]).to have_content("Blue")
      expect(variant_rows[3]).to have_content("Large")
    end
  end

  describe "variant pricing" do
    it "allows setting different prices for variants" do
      sign_in_as(user)
      product = create(:product_with_options, name: "Pricing Test", account: account)
      
      visit edit_account_product_path(account, product)
      
      # Set different prices for variants
      variant_rows = page.all("tbody tr")
      within variant_rows[0] do
        fill_in "Price", with: "99.99"
      end
      
      within variant_rows[1] do  
        fill_in "Price", with: "129.99"
      end
      
      click_button "Update Product"
      
      expect(page).to have_content("Product was successfully updated")
      expect(page).to have_field("Price", with: "99.99")
      expect(page).to have_field("Price", with: "129.99")
    end

    it "validates price is numeric and positive" do
      sign_in_as(user)
      product = create(:product_with_options, account: account)
      
      visit edit_account_product_path(account, product)
      
      # Try invalid price
      variant_rows = page.all("tbody tr")
      within variant_rows.first do
        fill_in "Price", with: "-10"
      end
      
      click_button "Update Product"
      
      expect(page).to have_content("Price must be greater than or equal to 0")
    end
  end

  describe "variant editing restrictions" do
    it "prevents editing SKUs of saved variants" do
      sign_in_as(user)
      product = create(:product_with_variants, account: account)
      
      visit edit_account_product_path(account, product)
      
      # SKU fields should be disabled for existing variants
      expect(page).to have_field("product[variants_attributes][0][sku]", disabled: true)
    end

    it "allows editing SKUs of unsaved variants" do
      sign_in_as(user)
      visit new_account_product_path(account)
      
      fill_in "product[name]", with: "New Product"
      fill_in "product[product_options_attributes][0][name]", with: "Color"
      all("button", text: "Add Value").first.click
      empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
      empty_input.set("Red") if empty_input
      
      click_button "Create Product"
      
      # For newly generated variants, SKU should be editable
      expect(page).to have_field("product[variants_attributes][0][sku]", disabled: false)
    end
  end
end