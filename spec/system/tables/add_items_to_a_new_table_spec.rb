require "rails_helper"

RSpec.describe "AddItemsToANewTable", type: :system do
  include CellInputHelper

  it "creates a product record" do
    sign_in_as(create(:user))

    click_on "Create New Table"

    expect(page).to have_selector("h1", text: "New Table")

    fill_in "Table Name", with: "Products"
    click_button "Create Table"

    expect(page).to have_selector("h1", text: "Products")
    expect(page).to have_selector(".notification", text: "A table must have at least one property column")
    expect(page).to have_selector("span", text: "Add Property")

    click_on "Add Property"

    click_on "Text"

    within "#table_view" do
      find('.dropdown', match: :first)

      expect(page).to have_selector("div", text: "Untitled")
    end

    expect(page).not_to have_selector(".notification", text: "A table must have at least one property column")

    last_property = Property.last

    within "#property-#{last_property.id}" do
      find('.dropdown', text: 'Untitled').click

      fill_in "property_name", with: "Name"

      click_button "Save"
    end

    expect(page).to have_selector("div", text: "Name")

    click_on "Add Item"

    within "#table_view" do
      expect(page).to have_selector("#item-1")
      expect(find_cell_input(Item.last.id, last_property.id).value).to eq('')
      expect(Item.count).to eq 1
    end

    last_item = Item.last

    find_cell_input(last_item.id, last_property.id).fill_in(with: "Test Product")
    find_cell_input(last_item.id, last_property.id).send_keys(:enter)

    fill_in "search", with: "Bad search"
    click_button "Search"

    within "#table_view" do
      expect(page).to have_no_selector("[data-item-id='#{last_item.id}'][data-property-id='#{last_property.id}']", wait: 5)
    end

    fill_in "search", with: "Test"
    click_button "Search"

    within "#table_view" do
      expect(find_cell_input(last_item.id, last_property.id).value).to eq "Test Product"
    end
  end
end
