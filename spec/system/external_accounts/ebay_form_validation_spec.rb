require "rails_helper"

RSpec.describe "eBay Form Validation", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }

  before do
    # Mock Rails credentials for eBay
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("test_ebay_client_id")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("test_ebay_client_secret")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :redirect_url).and_return("http://localhost:3000/external_accounts/ebay_callback")
    
    # Mock webhook registration
    allow_any_instance_of(ExternalAccount).to receive(:register_shopify_webhooks)
  end

  it "submits eBay service selection without requiring domain" do
    sign_in_as(user)
    visit new_account_external_account_path(account)

    select "eBay", from: "external_account[service_name]"
    
    # Debug: let's see what's on the page before submitting
    puts "Page content before submit:"
    puts page.body if ENV['DEBUG']
    
    # Capture any validation errors by checking if we stay on the same page
    expect(page).to have_button("Connect Account")
    
    click_button "Connect Account"
    
    # If there are validation errors, we'll stay on the same page
    # If successful, we should be redirected (either to OAuth or error page)
    if page.has_content?("Connect External Account")
      # We're still on the form page, check for errors
      puts "Stayed on form page. Page content:"
      puts page.body if ENV['DEBUG']
      
      # Check for validation errors
      expect(page).not_to have_content("can't be blank")
      expect(page).not_to have_content("is not included in the list")
    else
      # We were redirected away, which means the form submitted successfully
      expect(page.current_url).not_to include("external_accounts/new")
    end
  end

  it "allows eBay to be selected in the service dropdown" do
    sign_in_as(user)
    visit new_account_external_account_path(account)

    expect(page).to have_select("external_account[service_name]", with_options: ["eBay"])
    
    select "eBay", from: "external_account[service_name]"
    
    # Verify eBay is selected
    expect(page).to have_select("external_account[service_name]", selected: "eBay")
  end
end