require "rails_helper"

RSpec.describe "SearchAndFilterRecords", type: :system do
  before(:each) do
    @user = create(:user)
    @table = create(:table, name: "Products", account: @user.accounts.first)
    text_property = create(:property, table: @table, type: "text", name: "Name")
    select_property = create(:property, table: @table, type: "select", name: "Color")
    create(:property_option, property: select_property, value: "Red")
    create(:property_option, property: select_property, value: "Green")
    create(:property_option, property: select_property, value: "Blue")
    @toast = create(:record, table: @table, properties: { text_property.id => "Toast", select_property.id => "Red" })
    @cheese = create(:record, table: @table, properties: { text_property.id => "Cheese", select_property.id => "Green" })
    @butter = create(:record, table: @table, properties: { text_property.id => "Butter", select_property.id => "Blue" })
  end

  it "search and filter records" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    within "#table_view" do
      expect(page).to have_selector("#record-#{@toast.id}")
      expect(page).to have_selector("#record-#{@cheese.id}")
      expect(page).to have_selector("#record-#{@butter.id}")
    end

    fill_in "search", with: "Bu"
    click_button "Search"

    within "#table_view" do
      expect(page).to have_selector("#record-#{@butter.id}")

      expect(page).not_to have_selector("#record-#{@toast.id}")
      expect(page).not_to have_selector("#record-#{@cheese.id}")
    end

    fill_in "search", with: "t"
    click_button "Search"

    within "#table_view" do
      expect(page).to have_selector("#record-#{@butter.id}")
      expect(page).to have_selector("#record-#{@toast.id}")

      expect(page).not_to have_selector("#record-#{@cheese.id}")
    end

    select "Color", from: "property_id"

    find('[data-filter-target="valueInput"]').select('Red')
    click_button "Add Filter"

    within "#table_view" do
      expect(page).to have_selector("#record-#{@toast.id}")

      expect(page).not_to have_selector("#record-#{@butter.id}")
      expect(page).not_to have_selector("#record-#{@cheese.id}")
    end
  end
end
