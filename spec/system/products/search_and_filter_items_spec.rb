require "rails_helper"

RSpec.describe "SearchAndFilterItems", type: :system do
  before do
    @table = create(:table, name: "Products")
    text_property = create(:property, table: @table, data_type: "text", name: "Name")
    select_property = create(:property, table: @table, data_type: "select", name: "Color")
    create(:property_option, property: select_property, value: "Red")
    create(:property_option, property: select_property, value: "Green")
    create(:property_option, property: select_property, value: "Blue")
    @toast = create(:item, table: @table, properties: { text_property.id => "Toast", select_property.id => "Red" })
    @cheese = create(:item, table: @table, properties: { text_property.id => "Cheese", select_property.id => "Green" })
    @butter = create(:item, table: @table, properties: { text_property.id => "Butter", select_property.id => "Blue" })
  end

  it "search and filter items" do
    visit table_path(@table)

    within "#products" do
      expect(page).to have_selector("#product-#{@toast.id}")
      expect(page).to have_selector("#product-#{@cheese.id}")
      expect(page).to have_selector("#product-#{@butter.id}")
    end

    fill_in "search", with: "Bu"
    click_button "Search"

    within "#products" do
      expect(page).to have_selector("#product-#{@butter.id}")

      expect(page).not_to have_selector("#product-#{@toast.id}")
      expect(page).not_to have_selector("#product-#{@cheese.id}")
    end

    fill_in "search", with: "t"
    click_button "Search"

    within "#products" do
      expect(page).to have_selector("#product-#{@butter.id}")
      expect(page).to have_selector("#product-#{@toast.id}")

      expect(page).not_to have_selector("#product-#{@cheese.id}")
    end

    select "Color", from: "property_id"

    find('[data-filter-target="valueInput"]').select('Red')
    click_button "Add Filter"

    within "#products" do
      expect(page).to have_selector("#product-#{@toast.id}")

      expect(page).not_to have_selector("#product-#{@butter.id}")
      expect(page).not_to have_selector("#product-#{@cheese.id}")
    end
  end
end
