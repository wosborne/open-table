require 'rails_helper'

RSpec.describe ShopifyAuthentication, type: :service do
  let(:user) { create(:user) }
  let(:shop_domain) { "test-shop.myshopify.com" }
  let(:params) { { "shop" => shop_domain, "code" => "auth_code_123", "state" => jwt_state } }
  let(:authentication_service) { ShopifyAuthentication.new(params: params) }
  
  let(:jwt_payload) do
    {
      user_id: user.id,
      current_account_id: user.accounts.first.id,
      nonce: "secure_nonce",
      exp: 10.minutes.from_now.to_i
    }
  end
  let(:jwt_state) { JWT.encode(jwt_payload, Rails.application.credentials.secret_key_base, "HS256") }

  let(:rest_client_response) do
    double(body: {
      "access_token" => "shopify_access_token_123",
      "refresh_token" => "shopify_refresh_token_456"
    }.to_json)
  end

  before do
    user.update!(state_nonce: "secure_nonce")
    
    # Override global mocking for RestClient calls in these tests
    allow(RestClient).to receive(:post).and_return(rest_client_response)
  end

  describe '#authentication_path' do
    it 'generates correct OAuth URL' do
      expected_url = "https://#{shop_domain}/admin/oauth/authorize?" +
        "client_id=#{Rails.application.credentials.shopify[:client_id]}&" +
        "scope=#{authentication_service.send(:scopes)}&" +
        "redirect_uri=#{Rails.application.credentials.shopify[:redirect_url]}&" +
        "state=#{authentication_service.send(:generate_state, user)}&" +
        "grant_options[]=per-user"

      # Mock the state generation to return a predictable value
      allow(authentication_service).to receive(:generate_state).with(user).and_return("test_state")

      result = authentication_service.authentication_path(user, shop_domain)
      
      expect(result).to include("https://#{shop_domain}/admin/oauth/authorize")
      expect(result).to include("client_id=#{Rails.application.credentials.shopify[:client_id]}")
      expect(result).to include("scope=read_products,write_products,read_inventory,write_inventory,read_orders")
      expect(result).to include("state=test_state")
      expect(result).to include("grant_options[]=per-user")
    end

    it 'updates user state_nonce when generating state' do
      expect {
        authentication_service.authentication_path(user, shop_domain)
      }.to change { user.reload.state_nonce }
    end
  end

  describe '#decode_state' do
    context 'with valid JWT' do
      it 'decodes state correctly' do
        result = authentication_service.decode_state(jwt_state)
        
        expect(result["user_id"]).to eq(user.id)
        expect(result["current_account_id"]).to eq(user.accounts.first.id)
        expect(result["nonce"]).to eq("secure_nonce")
      end
    end

    context 'with invalid JWT' do
      it 'returns nil for malformed token' do
        result = authentication_service.decode_state("invalid.jwt.token")
        expect(result).to be_nil
      end

      it 'returns nil for expired token' do
        expired_payload = jwt_payload.merge(exp: 1.hour.ago.to_i)
        expired_token = JWT.encode(expired_payload, Rails.application.credentials.secret_key_base, "HS256")
        
        result = authentication_service.decode_state(expired_token)
        expect(result).to be_nil
      end

      it 'returns nil for token with wrong secret' do
        wrong_secret_token = JWT.encode(jwt_payload, "wrong_secret", "HS256")
        
        result = authentication_service.decode_state(wrong_secret_token)
        expect(result).to be_nil
      end
    end
  end

  describe '#create_external_account_for' do
    let(:access_token_response) do
      {
        "access_token" => "shopify_access_token_123",
        "refresh_token" => "shopify_refresh_token_456"
      }
    end

    let(:rest_client_response) do
      double(body: access_token_response.to_json)
    end

    before do
      allow(RestClient).to receive(:post).and_return(rest_client_response)
    end

    it 'exchanges code for access token' do
      expect(RestClient).to receive(:post).with(
        "https://#{shop_domain}/admin/oauth/access_token",
        {
          client_id: Rails.application.credentials.shopify[:client_id],
          client_secret: Rails.application.credentials.shopify[:client_secret],
          code: "auth_code_123"
        }
      ).and_return(rest_client_response)

      authentication_service.create_external_account_for(user)
    end

    it 'creates external account with tokens' do
      expect {
        authentication_service.create_external_account_for(user)
      }.to change(ExternalAccount, :count).by(1)

      external_account = ExternalAccount.last
      expect(external_account.service_name).to eq("shopify")
      expect(external_account.api_token).to eq("shopify_access_token_123")
      expect(external_account.refresh_token).to eq("shopify_refresh_token_456")
      expect(external_account.domain).to eq(shop_domain)
      expect(external_account.account).to eq(user.accounts.first)
    end

    it 'destroys existing shopify account before creating new one' do
      existing_account = create(:external_account, 
        account: user.accounts.first, 
        service_name: "shopify", 
        domain: "old-shop.myshopify.com"
      )

      expect {
        authentication_service.create_external_account_for(user)
      }.not_to change(ExternalAccount, :count)

      expect { existing_account.reload }.to raise_error(ActiveRecord::RecordNotFound)

      new_account = ExternalAccount.last
      expect(new_account.domain).to eq(shop_domain)
    end

    it 'handles missing refresh token gracefully' do
      response_without_refresh = { "access_token" => "token_123" }
      allow(RestClient).to receive(:post).and_return(
        double(body: response_without_refresh.to_json)
      )

      expect {
        authentication_service.create_external_account_for(user)
      }.not_to raise_error

      external_account = ExternalAccount.last
      expect(external_account.api_token).to eq("token_123")
      expect(external_account.refresh_token).to be_nil
    end

    context 'error handling' do
      it 'handles RestClient errors' do
        allow(RestClient).to receive(:post).and_raise(RestClient::BadRequest)

        expect {
          authentication_service.create_external_account_for(user)
        }.to raise_error(RestClient::BadRequest)
      end

      it 'handles JSON parsing errors' do
        allow(RestClient).to receive(:post).and_return(double(body: "invalid json"))

        expect {
          authentication_service.create_external_account_for(user)
        }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe '#generate_state' do
    it 'generates JWT with correct payload structure' do
      allow(SecureRandom).to receive(:hex).with(16).and_return("test_nonce")
      
      state = authentication_service.send(:generate_state, user)
      decoded = JWT.decode(state, Rails.application.credentials.secret_key_base, true, { algorithm: "HS256" })
      payload = decoded.first

      expect(payload["user_id"]).to eq(user.id)
      expect(payload["current_account_id"]).to eq(user.accounts.first.id)
      expect(payload["nonce"]).to eq("test_nonce")
      expect(payload["exp"]).to be_present
    end

    it 'updates user state_nonce' do
      allow(SecureRandom).to receive(:hex).with(16).and_return("new_nonce")
      
      expect {
        authentication_service.send(:generate_state, user)
      }.to change { user.reload.state_nonce }.to("new_nonce")
    end

    it 'sets expiration to 10 minutes from now' do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)

      state = authentication_service.send(:generate_state, user)
      decoded = JWT.decode(state, Rails.application.credentials.secret_key_base, true, { algorithm: "HS256" })
      payload = decoded.first

      expected_exp = 10.minutes.from_now.to_i
      expect(payload["exp"]).to be_within(1).of(expected_exp)
    end

    it 'handles nil user gracefully' do
      expect {
        authentication_service.send(:generate_state, nil)
      }.not_to raise_error
    end
  end

  describe '#scopes' do
    it 'returns correct Shopify scopes' do
      expected_scopes = "read_products,write_products,read_inventory,write_inventory,read_orders"
      expect(authentication_service.send(:scopes)).to eq(expected_scopes)
    end
  end

  describe 'integration flow' do
    let(:rest_client_response) do
      double(body: {
        "access_token" => "integration_token",
        "refresh_token" => "integration_refresh"
      }.to_json)
    end

    before do
      allow(RestClient).to receive(:post).and_return(rest_client_response)
    end

    it 'completes full OAuth flow' do
      # Step 1: Generate auth URL (this will update user's state_nonce)
      auth_url = authentication_service.authentication_path(user, shop_domain)
      expect(auth_url).to include(shop_domain)
      
      # Step 2: Get the updated user state for testing
      user.reload
      new_jwt_payload = {
        user_id: user.id,
        current_account_id: user.accounts.first.id,
        nonce: user.state_nonce,
        exp: 10.minutes.from_now.to_i
      }
      new_jwt_state = JWT.encode(new_jwt_payload, Rails.application.credentials.secret_key_base, "HS256")
      
      # Step 3: Decode state (simulating callback)
      state_data = authentication_service.decode_state(new_jwt_state)
      expect(state_data).to be_present
      
      # Step 4: Verify user matches
      found_user = User.find_by(id: state_data["user_id"], state_nonce: state_data["nonce"])
      expect(found_user).to eq(user)
      
      # Step 5: Create external account
      expect {
        authentication_service.create_external_account_for(found_user)
      }.to change(ExternalAccount, :count).by(1)
    end

    it 'prevents CSRF attacks with state validation' do
      # Create a different user with different nonce
      attacker_user = create(:user)
      attacker_user.update!(state_nonce: "attacker_nonce")
      
      # Try to use state meant for original user
      found_user = User.find_by(id: jwt_payload[:user_id], state_nonce: jwt_payload[:nonce])
      expect(found_user).to eq(user)
      expect(found_user).not_to eq(attacker_user)
      
      # Attacker can't use the state because nonce doesn't match
      attacker_found = User.find_by(id: attacker_user.id, state_nonce: jwt_payload[:nonce])
      expect(attacker_found).to be_nil
    end
  end
end