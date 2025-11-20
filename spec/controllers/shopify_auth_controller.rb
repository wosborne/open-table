require 'rails_helper'

RSpec.describe ShopifyAuthController, type: :controller do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let!(:account_user) { create(:account_user, account:, user:) }

  describe "GET #callback" do
    let(:state) do
      payload = {
        user_id: user.id,
        nonce: SecureRandom.hex(16),
        exp: 10.minutes.from_now.to_i
      }
      JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
    end

    it "redirects to root if user not found" do
      get :callback, params: { state:, code: "test_code" }
      expect(response).to redirect_to(root_path)
    end

    it "creates external account and redirects to account page" do
      user.update!(state_nonce: JWT.decode(state, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' }).first["nonce"])
      get :callback, params: { state:, code: "test_code" }
      expect(response).to redirect_to(account_tables_path(user.accounts.first.slug))
      expect(flash[:notice]).to eq("Shopify account connected successfully!")
    end
  end
end
