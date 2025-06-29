require "rails_helper"

RSpec.describe "Product form", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }

  it "creates a product with variants and shows validation errors" do
    sign_in_as(user)

    visit new_account_product_path(account)

    fill_in "Name", with: "iPhone 15"

    # Add a variant
    click_on "Add Variant" # Adjust this selector if your UI uses a different button

    within all(".nested-form-wrapper").last do
      fill_in "Name", with: "Black 128GB"
      fill_in "Price", with: "799"
    end

    # Add another variant with missing name to trigger validation
    click_on "Add Variant"
    within all(".nested-form-wrapper").last do
      fill_in "Price", with: "899"
    end

    click_button "Create Product"

    # Should see validation error for missing name
    expect(page).to have_content("Name can't be blank")

    # Fill in the missing name and resubmit
    within all(".nested-form-wrapper").last do
      fill_in "Name", with: "White 256GB"
    end

    click_button "Create Product"

    expect(page).to have_content("Product was successfully created")
    expect(page).to have_content("iPhone 15")

    find("td", text: "iPhone 15").click

    expect(page).to have_field("product[variants_attributes][0][name]", with: "Black 128GB")
    expect(page).to have_field("product[variants_attributes][1][name]", with: "White 256GB")
    expect(page).to have_content("SKU") # Should show generated SKUs
    expect(page).to have_field("product[variants_attributes][0][price]", with: "799.0")
    expect(page).to have_field("product[variants_attributes][1][price]", with: "899.0")
  end

  it "removes a variant before saving" do
    sign_in_as(user)
    visit new_account_product_path(account)
    fill_in "Name", with: "Pixel 9"

    click_on "Add Variant"
    within all(".nested-form-wrapper").last do
      fill_in "Name", with: "Blue 128GB"
      fill_in "Price", with: "699"
    end

    click_on "Add Variant"
    within all(".nested-form-wrapper").last do
      fill_in "Name", with: "Green 256GB"
      fill_in "Price", with: "799"
    end

    # Remove the last variant
    within all(".nested-form-wrapper").last do
      click_on(class: "button is-danger is-small")
    end

    click_button "Create Product"

    expect(page).to have_content("Product was successfully created")
    expect(page).to have_content("Pixel 9")

    find("td", text: "Pixel 9").click

    expect(page).to have_field("product[variants_attributes][0][name]", with: "Blue 128GB")
    expect(page).not_to have_field("product[variants_attributes][1][name]", with: "Green 256GB")
  end
end
