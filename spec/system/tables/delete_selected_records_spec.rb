require "rails_helper"

RSpec.describe "Delete selected records", type: :system do
  include CellInputHelper

  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, type: "text", name: "Name")
    @toast = create(:record, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:record, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:record, table: @table, properties: { @property.id => "Butter" })
  end

  it "deletes selected records and removes rows on table ui" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    expect(@table.records.count).to eq(3)

    within "#table_view" do
      expect(find_cell_input(@toast.id, @property.id).value).to eq "Toast"
      expect(find_cell_input(@cheese.id, @property.id).value).to eq "Cheese"
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    find("input[type='checkbox'][aria-label='Select record #{@toast.id}']").set(true)
    find("input[type='checkbox'][aria-label='Select record #{@cheese.id}']").set(true)

    find("button[aria-label='Delete selected records']").click

    within "#table_view" do
      expect(page).to have_no_selector("[data-record-id='#{@toast.id}'][data-property-id='#{@property.id}']")
      expect(page).to have_no_selector("[data-record-id='#{@cheese.id}'][data-property-id='#{@property.id}']")
      expect(find_cell_input(@butter.id, @property.id).value).to eq "Butter"
    end

    expect(@table.records.count).to eq(1)
  end
end
