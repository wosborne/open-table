require "rails_helper"

RSpec.describe "ChangingPropetyDataType", type: :system do
  include CellInputHelper

  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, type: "text", name: "Name")
    @toast = create(:record, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:record, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:record, table: @table, properties: { @property.id => "Butter" })
  end

  it "changing property type updates columns and cells accordingly" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    within "#table_view" do
      expect(find_cell_input(@toast.id, @property.id).value).to eq "Toast"
      expect(find_cell_input(@cheese.id, @property.id).value).to eq "Cheese"
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    # Change the property data type to select
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "select", from: "property_type"

      expect(page).to have_field(with: 'Toast')
      expect(page).to have_field(with: 'Cheese')
      expect(page).to have_field(with: 'Butter')

      find('button', text: 'Save').click
    end

    within "#table_view" do
      expect(page).to have_no_selector("input[data-record-id='#{@toast.id}'][data-property-id='#{@property.id}']", wait: 5)

      expect(find_cell_input(@toast.id, @property.id).value).to eq "Toast"
      expect(find_cell_input(@cheese.id, @property.id).value).to eq "Cheese"
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"

      expect(find_cell_input(@toast.id, @property.id).tag_name).to eq "select"
      expect(find_cell_input(@cheese.id, @property.id).tag_name).to eq "select"
      expect(find_cell_input(@butter.id, @property.id).tag_name).to eq "select"
    end

    # Change the property data type to number
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "number", from: "property_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).to have_no_selector("select[data-record-id='#{@toast.id}'][data-property-id='#{@property.id}']", wait: 5)

      expect(find_cell_input(@toast.id, @property.id)[:type]).to eq "number"
      expect(find_cell_input(@cheese.id, @property.id)[:type]).to eq "number"
      expect(find_cell_input(@butter.id, @property.id)[:type]).to eq "number"
    end

    # Change the property data type to text
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "text", from: "property_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).to have_no_selector("input[type='number'][data-record-id='#{@toast.id}'][data-property-id='#{@property.id}']", wait: 5)

      expect(find_cell_input(@toast.id, @property.id)[:type]).to eq "text"
      expect(find_cell_input(@cheese.id, @property.id)[:type]).to eq "text"
      expect(find_cell_input(@butter.id, @property.id)[:type]).to eq "text"

      expect(find_cell_input(@toast.id, @property.id).value).to eq "Toast"
      expect(find_cell_input(@cheese.id, @property.id).value).to eq "Cheese"
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    # Change the property data type to date
    within "#property-#{@property.id}" do
      find('.dropdown-trigger', text: 'Name').click

      select "date", from: "property_type"

      click_button "Save"
    end

    within "#table_view" do
      expect(page).to have_selector("input[type='text'][data-record-id='#{@toast.id}'][data-property-id='#{@property.id}'][data-controller='date-picker']", wait: 5)
    end
  end
end
