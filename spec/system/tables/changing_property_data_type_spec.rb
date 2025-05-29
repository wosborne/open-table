require "rails_helper"

RSpec.describe "ChangingPropetyDataType", type: :system do
  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, data_type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:item, table: @table, properties: { @property.id => "Butter" })
  end

  it "changing property type updates columns and cells accordingly" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    within "#table_view" do
      expect(page).to have_field("item-#{@toast.id}-property-#{@property.id}-input", with: 'Toast')
      expect(page).to have_field("item-#{@cheese.id}-property-#{@property.id}-input", with: 'Cheese')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", with: 'Butter')
    end

    # Change the property data type to select
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "select", from: "property_data_type"

      expect(page).to have_field("options_value", with: 'Toast')
      expect(page).to have_field("options_value", with: 'Cheese')
      expect(page).to have_field("options_value", with: 'Butter')

      find('button', text: 'Save').click
    end

    within "#table_view" do
      expect(page).to have_select("item-#{@toast.id}-property-#{@property.id}-input", selected: 'Toast')
      expect(page).to have_select("item-#{@cheese.id}-property-#{@property.id}-input", selected: 'Cheese')
      expect(page).to have_select("item-#{@butter.id}-property-#{@property.id}-input", selected: 'Butter')
    end

    # Change the property data type to number
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "number", from: "property_data_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).not_to have_select("item-#{@toast.id}-property-#{@property.id}-input", selected: 'Toast')
      expect(page).not_to have_select("item-#{@cheese.id}-property-#{@property.id}-input", selected: 'Cheese')
      expect(page).not_to have_select("item-#{@butter.id}-property-#{@property.id}-input", selected: 'Butter')

      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", with: '')
    end

    # Change the property data type to text
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "text", from: "property_data_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).to have_field("item-#{@toast.id}-property-#{@property.id}-input", with: 'Toast')
      expect(page).to have_field("item-#{@cheese.id}-property-#{@property.id}-input", with: 'Cheese')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", with: 'Butter')
    end

    # Change the property data type to date
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "date", from: "property_data_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).to have_field("item-#{@toast.id}-property-#{@property.id}-input", type: 'date')
      expect(page).to have_field("item-#{@cheese.id}-property-#{@property.id}-input", type: 'date')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", type: 'date')
    end
  end
end
