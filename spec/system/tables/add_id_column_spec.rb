require "rails_helper"

RSpec.describe "Add ID Column", type: :system do
  before(:each) do
    @user = create(:user)
    @table = create(:table, name: "Products", account: @user.accounts.first)
    text_property = create(:property, table: @table, type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { text_property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { text_property.id => "Cheese" })
  end

  it "allows users to create a unique id column with a prefix" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    click_on "Add Property"

    click_on "ID"

    expect(page).to have_text "Untitled"

    within "#item-#{@toast.id}" do
      expect(page).to have_field(with: "Toast")
      expect(page).to have_field(with: "1", disabled: true)
    end

    within "#item-#{@cheese.id}" do
      expect(page).to have_field(with: "Cheese")
      expect(page).to have_field(with: "2", disabled: true)
    end

    property = Property.last

    within "#property-#{property.id}" do
      find('.dropdown-trigger', text: 'Untitled').click

      fill_in "property_name", with: "ID"

      fill_in "property_prefix", with: "PRO"

      find('button', text: 'Save').click
    end

    within "#item-#{@toast.id}" do
      expect(page).to have_field(with: "Toast")
      expect(page).to have_field(with: "PRO-1", disabled: true)
    end

    within "#item-#{@cheese.id}" do
      expect(page).to have_field(with: "Cheese")
      expect(page).to have_field(with: "PRO-2", disabled: true)
    end
  end
end
