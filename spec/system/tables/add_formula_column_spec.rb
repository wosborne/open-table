require "rails_helper"

RSpec.describe "Add Formula Column", type: :system do
  before(:each) do
    @user = create(:user)
    @table = create(:table, name: "Products", account: @user.accounts.first)
    @first_number_property = create(:property, table: @table, type: "number", name: "First Number")
    @second_number_property = create(:property, table: @table, type: "number", name: "Second Number")
    text_property = create(:property, table: @table, type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { text_property.id => "Toast", @first_number_property.id => "2", @second_number_property.id => "3" })
    @cheese = create(:item, table: @table, properties: { text_property.id => "Cheese", @first_number_property.id => "2", @second_number_property.id => "4" })
  end

  it "allows users to create formulas with number columns" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    click_on "Add Property"

    expect(page).to have_text "Untitled"

    property = Property.last

    within "#property-#{property.id}" do
      find('.dropdown-trigger', text: 'Untitled').click

      fill_in "property_name", with: "Formula"

      select "formula", from: "property_type"

      expect(page).to have_button "Edit Formula"

      click_on "Edit Formula"

      within ".formula-panel-content" do
        expect(page).to have_text "Formula builder"
        expect(page).to have_text "First Number"
        expect(page).to have_text "Second Number"
        expect(page).not_to have_text "Name"

        find("a[data-id='#{@first_number_property.id}']", text: 'First Number').click

        find("textarea").send_keys("*")

        find("a[data-id='#{@second_number_property.id}']", text: 'Second Number').click

        click_on "Accept"
      end

      find('button', text: 'Save').click
    end


    within "#item-#{@toast.id}" do
      expect(page).to have_field(with: "1")
      expect(page).to have_field(with: "3")
      expect(page).to have_field(with: "6")
    end


    within "#item-#{@cheese.id}" do
      expect(page).to have_field(with: "2")
      expect(page).to have_field(with: "4")
      expect(page).to have_field(with: "8")
    end
  end
end
