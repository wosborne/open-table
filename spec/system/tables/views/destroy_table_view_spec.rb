require "rails_helper"

RSpec.describe "Destroy Table View", type: :system do
  before(:each) do
    @user = create(:user)

    @table = create(:table, name: "Products", account: @user.accounts.first)
    @property = create(:property, table: @table, data_type: "text", name: "Name")
    @toast = create(:item, table: @table, properties: { @property.id => "Toast" })
    @cheese = create(:item, table: @table, properties: { @property.id => "Cheese" })
    @butter = create(:item, table: @table, properties: { @property.id => "Butter" })
    @property.update(data_type: "select")
    @view = create(:view, table: @table, name: "Toast")
  end

  it "destroys a table view" do
    sign_in_as(@user)

    visit account_table_path(@user.accounts.first, @table)

    expect(page).to have_link("Everything")
    expect(page).to have_link("Toast")

    within ".tabs" do
      click_on "Toast"
      find('[aria-label="Open Toast view settings"]').click

      expect(page).to have_text("Filters")
      find('[aria-label="Destroy Toast view"]').click
    end

    expect(page).not_to have_link("Toast")
    expect(page).to have_text("View was successfully deleted.")
  end
end
