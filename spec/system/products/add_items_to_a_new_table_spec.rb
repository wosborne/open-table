require "rails_helper"

RSpec.describe "AddItemsToANewTable", type: :system do
  before do
  end

  it "creates a product record" do
    visit root_path
    click_on "Create New Table"

    fill_in "Table Name", with: "Products"
    click_button "Create Table"

    expect(page).to have_selector("h1", text: "Products")
    expect(page).to have_selector("span", text: "Add Item")
    expect(page).to have_selector("span", text: "Add Property")

    click_on "Add Property"

    expect(page).to have_selector("div", text: "Untitled")

    last_property = Property.last

    within "#property-#{last_property.id}" do
      find('.dropdown-trigger', text: 'Untitled').click

      fill_in "property_name", with: "Name"

      click_button "Save"
    end

    expect(page).to have_selector("div", text: "Name")

    click_on "Add Item"

    within "#products" do
      expect(Item.count).to eq 1
      expect(page).to have_field("item-#{Item.last.id}-property-#{last_property.id}-input", with: '')
    end

    last_item = Item.last

    fill_in "item-#{last_item.id}-property-#{last_property.id}-input", with: "Test Product"
    find("#item-#{last_item.id}-property-#{last_property.id}-input").send_keys(:enter)

    fill_in "search", with: "Bad search"
    click_button "Search"

    within "#products" do
      expect(page).not_to have_field("item-#{last_item.id}-property-#{last_property.id}-input", with: 'Test Product')
    end

    fill_in "search", with: "Test"
    click_button "Search"

    within "#products" do
      expect(page).to have_field("item-#{last_item.id}-property-#{last_property.id}-input", with: 'Test Product')
    end
  end
end
