require "rails_helper"

RSpec.describe "eBay Integration", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.accounts.first }

  before do
    # Mock Rails credentials for eBay
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("test_ebay_client_id")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("test_ebay_client_secret")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :redirect_url).and_return("http://localhost:3000/external_accounts/ebay_callback")
    
    # Mock external service factory to prevent API calls
    allow(ExternalServiceFactory).to receive(:for).and_call_original
    
    # Mock webhook registration to prevent API calls
    allow_any_instance_of(ExternalAccount).to receive(:register_shopify_webhooks)
  end

  describe "Account settings page" do
    it "shows eBay connection card with connect button when not connected" do
      sign_in_as(user)
      visit edit_account_path(account)

      expect(page).to have_content("eBay")
      expect(page).to have_content("Not Connected")
      expect(page).to have_link("Connect eBay")
      expect(page).not_to have_button("Disconnect", exact: false)
    end

    it "shows eBay as connected with disconnect button when connected" do
      # Create an eBay external account
      ebay_account = create(:external_account, account: account, service_name: "ebay", domain: "ebay.com")
      
      sign_in_as(user)
      visit edit_account_path(account)

      expect(page).to have_content("eBay")
      expect(page).to have_content("Connected")
      expect(page).to have_button("Disconnect")
      expect(page).not_to have_link("Connect eBay")
    end

    it "shows both Shopify and eBay cards" do
      sign_in_as(user)
      visit edit_account_path(account)

      expect(page).to have_content("Shopify")
      expect(page).to have_content("eBay")
    end
  end

  describe "eBay connection flow" do
    it "navigates to connection form when clicking Connect eBay" do
      sign_in_as(user)
      visit edit_account_path(account)

      click_link "Connect eBay"

      expect(page).to have_current_path(new_account_external_account_path(account, service: "ebay"))
      expect(page).to have_content("Connect External Account")
      expect(page).to have_content("Connect your marketplace to sync inventory")
    end

    it "pre-selects eBay service when coming from Connect eBay button" do
      sign_in_as(user)
      visit new_account_external_account_path(account, service: "ebay")

      expect(page).to have_select("external_account[service_name]", selected: "eBay")
    end

    it "hides domain field when eBay is selected" do
      sign_in_as(user)
      visit new_account_external_account_path(account)

      select "eBay", from: "external_account[service_name]"

      # Domain field should be hidden for eBay
      expect(page).not_to have_field("external_account[domain]", visible: true)
    end

    it "shows domain field when Shopify is selected" do
      sign_in_as(user)
      visit new_account_external_account_path(account)

      select "Shopify", from: "external_account[service_name]"

      # Domain field should be visible for Shopify
      expect(page).to have_field("external_account[domain]", visible: true)
      expect(page).to have_content("Enter your Shopify store domain")
    end

    it "attempts to redirect to eBay OAuth when submitting eBay connection" do
      sign_in_as(user)
      visit new_account_external_account_path(account)

      select "eBay", from: "external_account[service_name]"
      click_button "Connect Account"

      # The form should attempt to redirect to eBay OAuth
      # We verify this by checking that we're redirected away from our app
      # (eBay will show an error due to test credentials, but that proves the integration works)
      expect(page.current_url).to include("ebay.com")
    end
  end

  describe "Disconnect eBay account" do
    it "removes eBay connection when clicking disconnect" do
      ebay_account = create(:external_account, account: account, service_name: "ebay", domain: "ebay.com")
      
      sign_in_as(user)
      visit edit_account_path(account)

      expect(page).to have_content("Connected")
      
      # Click disconnect button (find the card containing eBay) and accept the alert
      within(".card", text: "eBay") do
        accept_alert do
          click_button "Disconnect"
        end
      end

      # Wait for page to reload and check that the eBay connection is gone
      expect(page).to have_content("Not Connected")
      expect(page).to have_link("Connect eBay")
      
      # Verify the account was actually deleted
      expect { ebay_account.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Service selection form" do
    it "toggles domain field visibility based on service selection" do
      sign_in_as(user)
      visit new_account_external_account_path(account)

      # Initially no service selected, domain should be hidden
      expect(page).not_to have_field("external_account[domain]", visible: true)

      # Select Shopify - domain should appear
      select "Shopify", from: "external_account[service_name]"
      expect(page).to have_field("external_account[domain]", visible: true)

      # Switch to eBay - domain should disappear
      select "eBay", from: "external_account[service_name]"
      expect(page).not_to have_field("external_account[domain]", visible: true)
    end

    it "includes both Shopify and eBay in service options" do
      sign_in_as(user)
      visit new_account_external_account_path(account)

      expect(page).to have_select("external_account[service_name]", 
        options: ["Select a service", "Shopify", "eBay"])
    end
  end

  describe "eBay callback handling" do
    it "creates external account on successful eBay callback" do
      # Mock successful eBay authentication
      allow_any_instance_of(EbayAuthentication).to receive(:decode_state).and_return({
        "user_id" => user.id,
        "nonce" => "test_nonce"
      })
      allow_any_instance_of(EbayAuthentication).to receive(:create_external_account_for) do |auth, user|
        user.accounts.first.external_accounts.create!(
          service_name: "ebay",
          api_token: "test_ebay_token",
          domain: "ebay.com"
        )
      end

      user.update!(state_nonce: "test_nonce")
      
      # Sign in user (simulating they were signed in when they initiated OAuth)
      sign_in_as(user)

      visit "/external_accounts/ebay_callback?code=test_code&state=test_state"

      expect(page).to have_content("eBay account connected successfully!")
      expect(account.reload.ebay_account).to be_present
    end
  end
end