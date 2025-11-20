require 'rails_helper'

RSpec.describe EbayAuthentication, type: :service do
  let(:user) { create(:user) }
  let(:params) { { "code" => "ebay_auth_code_123", "state" => jwt_state } }
  let(:authentication_service) { EbayAuthentication.new(params: params) }

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
      "access_token" => "ebay_access_token_123",
      "refresh_token" => "ebay_refresh_token_456"
    }.to_json)
  end

  before do
    user.update!(state_nonce: "secure_nonce")

    # Mock Rails credentials for eBay
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_id).and_return("ebay_client_id")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :client_secret).and_return("ebay_client_secret")
    allow(Rails.application.credentials).to receive(:dig).with(:ebay, :redirect_url).and_return("https://app.test/auth/ebay/callback")

    # Mock RestClient calls
    allow(RestClient).to receive(:post).and_return(rest_client_response)
  end

  describe '#authentication_path' do
    it 'generates correct eBay OAuth URL' do
      expected_base = "https://auth.ebay.com/oauth2/authorize?"

      # Mock the state generation to return a predictable value
      allow(authentication_service).to receive(:generate_state).with(user).and_return("test_state")

      result = authentication_service.authentication_path(user)

      expect(result).to include(expected_base)
      expect(result).to include("client_id=ebay_client_id")
      expect(result).to include("response_type=code")
      expect(result).to include("redirect_uri=https://app.test/auth/ebay/callback")
      expect(result).to include("state=test_state")
      expect(result).to include("scope=")
    end

    it 'includes correct eBay scopes' do
      allow(authentication_service).to receive(:generate_state).with(user).and_return("test_state")

      result = authentication_service.authentication_path(user)

      # Just check that the scope parameter is present and contains expected scope substrings
      expect(result).to include("scope=")
      expect(result).to include("api.ebay.com/oauth/api_scope")
      expect(result).to include("sell.marketing")
      expect(result).to include("sell.inventory")
    end

    it 'updates user state_nonce when generating state' do
      expect {
        authentication_service.authentication_path(user)
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
        "access_token" => "ebay_access_token_123",
        "refresh_token" => "ebay_refresh_token_456"
      }
    end

    let(:rest_client_response) do
      double(body: access_token_response.to_json)
    end

    before do
      allow(RestClient).to receive(:post).and_return(rest_client_response)
    end

    it 'exchanges code for access token with correct eBay endpoint' do
      expected_auth_header = Base64.strict_encode64("ebay_client_id:ebay_client_secret")

      expect(RestClient).to receive(:post).with(
        "https://api.ebay.com/identity/v1/oauth2/token",
        {
          grant_type: "authorization_code",
          code: "ebay_auth_code_123",
          redirect_uri: "https://app.test/auth/ebay/callback"
        },
        {
          "Authorization" => "Basic #{expected_auth_header}",
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      ).and_return(rest_client_response)

      authentication_service.create_external_account_for(user)
    end

    it 'creates external account with tokens' do
      expect {
        authentication_service.create_external_account_for(user)
      }.to change(ExternalAccount, :count).by(1)

      external_account = ExternalAccount.last
      expect(external_account.service_name).to eq("ebay")
      expect(external_account.api_token).to eq("ebay_access_token_123")
      expect(external_account.refresh_token).to eq("ebay_refresh_token_456")
      expect(external_account.domain).to eq("ebay.com")
      expect(external_account.account).to eq(user.accounts.first)
    end

    it 'destroys existing eBay account before creating new one' do
      existing_account = create(:external_account,
        account: user.accounts.first,
        service_name: "ebay",
        domain: "ebay.com"
      )

      expect {
        authentication_service.create_external_account_for(user)
      }.not_to change(ExternalAccount, :count)

      expect { existing_account.reload }.to raise_error(ActiveRecord::RecordNotFound)

      new_account = ExternalAccount.last
      expect(new_account.domain).to eq("ebay.com")
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
    it 'returns correct eBay scopes' do
      expected_scopes = "https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/sell.marketing.readonly https://api.ebay.com/oauth/api_scope/sell.marketing https://api.ebay.com/oauth/api_scope/sell.inventory.readonly https://api.ebay.com/oauth/api_scope/sell.inventory"
      expect(authentication_service.send(:scopes)).to eq(expected_scopes)
    end
  end

  describe '#auth_header' do
    it 'generates correct Basic auth header' do
      expected_credentials = "ebay_client_id:ebay_client_secret"
      expected_header = Base64.strict_encode64(expected_credentials)

      result = authentication_service.send(:auth_header)
      expect(result).to eq(expected_header)
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

    it 'completes full eBay OAuth flow' do
      # Step 1: Generate auth URL (this will update user's state_nonce)
      auth_url = authentication_service.authentication_path(user)
      expect(auth_url).to include("auth.ebay.com")

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

      # Verify it's an eBay account
      external_account = ExternalAccount.last
      expect(external_account.service_name).to eq("ebay")
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
