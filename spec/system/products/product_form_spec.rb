require "rails_helper"

RSpec.describe "Product form", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }

  it "creates a product with variants and shows validation errors" do
    sign_in_as(user)

    visit new_account_product_path(account)

    fill_in "product[name]", with: "iPhone 15"

    # Add an option (e.g. Color)
    fill_in "product[product_options_attributes][0][name]", with: "Color"
    # Add option values
    all("button", text: "Add Value").first.click
    empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
    empty_input.set("Black") if empty_input
    all("button", text: "Add Value").first.click
    empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
    empty_input.set("White") if empty_input
    click_button "Create Product"

    expect(page).to have_content("Product was successfully created")
    expect(page).to have_field("product[name]", with: "iPhone 15")

    # Now set prices for generated variants
    within all('tr').find { |tr| tr.has_text?('Black') } do
      fill_in "Price", with: "799"
    end
    within all('tr').find { |tr| tr.has_text?('White') } do
      fill_in "Price", with: "899"
    end
    click_button "Update Product"

    expect(page).to have_content("Product was successfully updated")
    expect(page).to have_field("product[name]", with: "iPhone 15")

    expect(page).to have_field("product[variants_attributes][0][price]", with: "799.0")
    expect(page).to have_field("product[variants_attributes][1][price]", with: "899.0")
  end

  it "removes an option value before saving" do
    sign_in_as(user)
    visit new_account_product_path(account)
    fill_in "product[name]", with: "Pixel 9"

    find(:css, "input[placeholder='Option name (e.g. Color)']", match: :first).set("Color")
    all("button", text: "Add Value").first.click
    empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
    empty_input.set("Blue") if empty_input
    all("button", text: "Add Value").first.click
    empty_input = all("input[placeholder='Value (e.g. Red)']").detect { |input| input.value.blank? }
    empty_input.set("Green") if empty_input
    # Remove the last value
    within all('.nested-form-wrapper').last do
      click_on(class: "button is-danger is-small")
    end

    click_button "Create Product"

    expect(page).to have_content("Product was successfully created")
    expect(page).to have_field("product[name]", with: "Pixel 9")

    # Only one variant should be generated
    within all('tr').find { |tr| tr.has_text?('Blue') } do
      fill_in "Price", with: "699"
    end
    click_button "Update Product"

    expect(page).to have_content("Product was successfully updated")
    expect(page).to have_field("product[name]", with: "Pixel 9")


    expect(page).to have_field("product[variants_attributes][0][price]", with: "699.0")
    expect(page).not_to have_field("product[variants_attributes][1][price]")
  end
end
