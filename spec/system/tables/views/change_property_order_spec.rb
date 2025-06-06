require "rails_helper"

RSpec.describe "Change Property Order", type: :system do
  before(:each) do
    @user = create(:user)
    @table = create(:table, name: "Products", account: @user.accounts.first)
    @text_property = create(:property, table: @table, data_type: "text", name: "Name")
    @select_property = create(:property, table: @table, data_type: "select", name: "Color")
    create(:property_option, property: @select_property, value: "Red")
    create(:property_option, property: @select_property, value: "Green")
    create(:property_option, property: @select_property, value: "Blue")
    @toast = create(:item, table: @table, properties: { @text_property.id => "Toast", @select_property.id => "Red" })
    @cheese = create(:item, table: @table, properties: { @text_property.id => "Cheese", @select_property.id => "Green" })
    @butter = create(:item, table: @table, properties: { @text_property.id => "Butter", @select_property.id => "Blue" })
    @table.reload
    @view = create(:view, table: @table, name: "Toast")
  end

  it "allows views to change their property order independent of eachother" do
    sign_in_as(@user)

    visit account_table_view_path(@user.accounts.first, @table, @view)
    within "#table_view" do
      expect(all('.dropdown-trigger.draggable')[0]).to have_text("Name")
      expect(all('.dropdown-trigger.draggable')[1]).to have_text("Color")

      all('.dropdown-trigger.draggable')[1].drag_to find("[data-table-target='selectAll']")

      expect(all('.dropdown-trigger.draggable')[1]).to have_text("Name")
      expect(all('.dropdown-trigger.draggable')[0]).to have_text("Color")
    end

    within ".tabs" do
      expect(page).to have_selector(".is-active", text: "Toast")

      click_on "Everything"

      expect(page).to have_selector(".is-active", text: "Everything")
    end

    within "#table_view" do
      expect(all('.dropdown-trigger.draggable')[0]).to have_text("Name")
      expect(all('.dropdown-trigger.draggable')[1]).to have_text("Color")
    end
  end
end
