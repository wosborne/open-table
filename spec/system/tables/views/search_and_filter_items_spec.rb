require "rails_helper"

RSpec.describe "SearchAndFilterItems", type: :system do
  before(:each) do
    @user = create(:user)
    @table = create(:table, name: "Products", account: @user.accounts.first)
    text_property = create(:property, table: @table, type: "text", name: "Name")
    select_property = create(:property, table: @table, type: "select", name: "Color")
    create(:property_option, property: select_property, value: "Red")
    create(:property_option, property: select_property, value: "Green")
    create(:property_option, property: select_property, value: "Blue")
    @toast = create(:item, table: @table, properties: { text_property.id => "Toast", select_property.id => "Red" })
    @cheese = create(:item, table: @table, properties: { text_property.id => "Cheese", select_property.id => "Green" })
    @butter = create(:item, table: @table, properties: { text_property.id => "Butter", select_property.id => "Blue" })
    @view = create(:view, table: @table, name: "Toast")
  end

  it "search and filter items" do
    sign_in_as(@user)

    visit account_table_view_path(@user.accounts.first, @table, @view)

    within "#table_view" do
      expect(page).to have_selector("#item-#{@toast.id}")
      expect(page).to have_selector("#item-#{@cheese.id}")
      expect(page).to have_selector("#item-#{@butter.id}")
    end

    fill_in "search", with: "Bu"
    click_button "Search"

    within "#table_view" do
      expect(page).to have_selector("#item-#{@butter.id}")

      expect(page).not_to have_selector("#item-#{@toast.id}")
      expect(page).not_to have_selector("#item-#{@cheese.id}")
    end

    fill_in "search", with: "t"
    click_button "Search"

    within "#table_view" do
      expect(page).to have_selector("#item-#{@butter.id}")
      expect(page).to have_selector("#item-#{@toast.id}")

      expect(page).not_to have_selector("#item-#{@cheese.id}")
    end

    select "Color", from: "property_id"

    find('[data-filter-target="valueInput"]').select('Red')
    click_button "Add Filter"

    within "#table_view" do
      expect(page).to have_selector("#item-#{@toast.id}")

      expect(page).not_to have_selector("#item-#{@butter.id}")
      expect(page).not_to have_selector("#item-#{@cheese.id}")
    end
  end
end
