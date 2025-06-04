require "rails_helper"

RSpec.describe "Delete selected items", type: :system do
  include CellInputHelper

  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, data_type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:item, table: @table, properties: { @property.id => "Butter" })
  end

  it "deletes selected items and removes rows on table ui" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    expect(@table.items.count).to eq(3)

    within "#table_view" do
      expect(find_cell_input(@toast.id, @property.id).value).to eq "Toast"
      expect(find_cell_input(@cheese.id, @property.id).value).to eq "Cheese"
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    find("input[type='checkbox'][aria-label='Select item #{@toast.id}']").set(true)
    find("input[type='checkbox'][aria-label='Select item #{@cheese.id}']").set(true)

    find("button[aria-label='Delete selected items']").click

    within "#table_view" do
      expect(page).to have_no_selector("[data-item-id='#{@toast.id}'][data-property-id='#{@property.id}']")
      expect(page).to have_no_selector("[data-item-id='#{@cheese.id}'][data-property-id='#{@property.id}']")
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    expect(@table.items.count).to eq(1)
  end
end
