require "rails_helper"

RSpec.describe "New User And Account", type: :system do
  it "sets up a new user and account with an inventory table" do
    visit root_path

    click_on "Sign up"

    expect(page).to have_selector("h1", text: "Sign up")

    fill_in "Email", with: "example@email.com"

    password = Faker::Internet.password(min_length: 8)
    fill_in "Password", with: password
    fill_in "Password confirmation", with: password
    click_button "Sign up"

    expect(page).to have_selector("h1", text: "New account")

    fill_in "Name", with: "Test Account"
    fill_in "Slug", with: "test-account"
    click_button "Create account"

    expect(page).to have_selector("h2", text: "Test Account")
    expect(page).to have_link("Create New Table")
    expect(page).to have_link("Inventory")
    expect(page).to have_link("Everything")

    click_on "Everything"

    expect(page).to have_selector('.dropdown-trigger', text: 'ID')
  end
end
