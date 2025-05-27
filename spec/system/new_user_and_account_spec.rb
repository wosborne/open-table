require "rails_helper"

RSpec.describe "NewUserAndAccount", type: :system do
  it "sets up a new user and account" do
    visit root_path

    expect(page).to have_selector("h1", text: "Log in")

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
  end
end
