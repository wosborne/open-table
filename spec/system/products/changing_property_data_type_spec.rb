require "rails_helper"

RSpec.describe "ChangingPropetyDataType", type: :system do
  before do
    @table = create(:table, name: "Products")
    @property = create(:property, table: @table, data_type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:item, table: @table, properties: { @property.id => "Butter" })
  end

  it "changing property type updates columns and cells accordingly" do
    visit table_path(@table)

    within "#products" do
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

      click_button "Save"
    end

    within "#products" do
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

    within "#products" do
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

    within "#products" do
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

    within "#products" do
      expect(page).to have_field("item-#{@toast.id}-property-#{@property.id}-input", type: 'date')
      expect(page).to have_field("item-#{@cheese.id}-property-#{@property.id}-input", type: 'date')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", type: 'date')
    end
  end
end
