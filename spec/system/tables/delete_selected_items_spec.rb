require "rails_helper"

RSpec.describe "Delete selected items", type: :system do
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
      expect(page).to have_field("item-#{@toast.id}-property-#{@property.id}-input", with: 'Toast')
      expect(page).to have_field("item-#{@cheese.id}-property-#{@property.id}-input", with: 'Cheese')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", with: 'Butter')
    end

    find("input[type='checkbox'][aria-label='Select item #{@toast.id}']").set(true)
    find("input[type='checkbox'][aria-label='Select item #{@cheese.id}']").set(true)

    find("button[aria-label='Delete selected items']").click

    within "#table_view" do
      expect(page).not_to have_field("item-#{@toast.id}-property-#{@property.id}-input", with: 'Toast')
      expect(page).not_to have_field("item-#{@cheese.id}-property-#{@property.id}-input", with: 'Cheese')
      expect(page).to have_field("item-#{@butter.id}-property-#{@property.id}-input", with: 'Butter')
    end

    expect(@table.items.count).to eq(1)
  end
end
