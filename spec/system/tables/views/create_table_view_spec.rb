require "rails_helper"

RSpec.describe "Create Table View", type: :system do
  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, data_type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:item, table: @table, properties: { @property.id => "Butter" })
    @property.update(data_type: "select")
  end

  it "creates a table view with set base filters" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    expect(page).to have_link("Everything")

    within "#table_view" do
      expect(page).to have_select("item-#{@toast.id}-property-#{@property.id}-input", selected: 'Toast')
      expect(page).to have_select("item-#{@cheese.id}-property-#{@property.id}-input", selected: 'Cheese')
      expect(page).to have_select("item-#{@butter.id}-property-#{@property.id}-input", selected: 'Butter')
    end

    click_on "Add View"

    within "aside" do
      expect(page).to have_link("New View")
    end

    within ".tabs" do
      expect(page).to have_link("New View")
      find("a", text: "New View").find(:xpath, '..').click
    end

    expect(page).to have_field("view_name", with: "New View")

    fill_in "view_name", with: "Toast"

    click_button "Save"

    within "aside" do
      expect(page).to have_link("Toast")
    end

    within ".tabs" do
      expect(page).to have_link("Toast")
    end

    within ".tabs" do
      find(".dropdown-trigger", match: :first).click

      expect(page).to have_text("Filters")
      find('#add-view-filter').click

      tab = find('[data-controller="filter-input"]', match: :first)

      tab.find('select', match: :first).select(@property.name)

      filter_input = tab.find('[data-filter-input-target="input"]', match: :first)
      filter_input.select('Toast')

      click_on "Save"
    end

    within "#table_view" do
      expect(page).to have_selector("#item-#{@toast.id}")

      expect(page).not_to have_selector("#item-#{@butter.id}")
      expect(page).not_to have_selector("#item-#{@cheese.id}")
    end
  end
end
