require 'rails_helper'

RSpec.describe Gmail, type: :model do
  include ActiveSupport::Testing::TimeHelpers
  let(:account) { create(:account) }
  let(:gmail) { create(:gmail, account: account) }

  describe 'associations' do
    it { should belong_to(:account) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:access_token) }
    it { should validate_presence_of(:refresh_token) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_gmail) { create(:gmail, active: true) }
      let!(:inactive_gmail) { create(:gmail, active: false) }

      it 'returns only active gmail integrations' do
        expect(Gmail.active).to include(active_gmail)
        expect(Gmail.active).not_to include(inactive_gmail)
      end
    end
  end

  describe '#token_expired?' do
    context 'when expires_at is in the past' do
      it 'returns true' do
        gmail.update!(expires_at: 1.hour.ago)
        expect(gmail.token_expired?).to be true
      end
    end

    context 'when expires_at is in the future' do
      it 'returns false' do
        gmail.update!(expires_at: 1.hour.from_now)
        expect(gmail.token_expired?).to be false
      end
    end

    context 'when expires_at is nil' do
      it 'returns true' do
        gmail.update!(expires_at: nil)
        expect(gmail.token_expired?).to be true
      end
    end
  end

  describe '#refresh_token!' do
    let(:mock_client) { instance_double(Signet::OAuth2::Client) }

    before do
      allow(Rails.application.credentials).to receive(:gmail).and_return(
        double(client_id: 'test_id', client_secret: 'test_secret')
      )
      allow(Signet::OAuth2::Client).to receive(:new).and_return(mock_client)
    end

    context 'when refresh token is present' do
      context 'and refresh is successful' do
        let(:credentials) do
          {
            'access_token' => 'new_access_token',
            'expires_in' => 3600
          }
        end

        before do
          allow(mock_client).to receive(:refresh!).and_return(credentials)
        end

        it 'updates access_token and expires_at' do
          travel_to Time.current do
            gmail.refresh_token!

            gmail.reload
            expect(gmail.access_token).to eq('new_access_token')
            expect(gmail.expires_at).to be_within(1.second).of(1.hour.from_now)
          end
        end

        it 'returns true' do
          expect(gmail.refresh_token!).to be true
        end
      end

      context 'and refresh fails' do
        before do
          allow(mock_client).to receive(:refresh!).and_raise(StandardError.new('OAuth error'))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs the error' do
          gmail.refresh_token!
          expect(Rails.logger).to have_received(:error).with('Failed to refresh Gmail token: OAuth error')
        end

        it 'returns false' do
          expect(gmail.refresh_token!).to be false
        end
      end
    end

    context 'when refresh token is blank' do
      before do
        gmail.update!(refresh_token: nil, active: false)
      end

      it 'returns nil without attempting refresh' do
        expect(Signet::OAuth2::Client).not_to receive(:new)
        expect(gmail.refresh_token!).to be_nil
      end
    end
  end

  describe '#gmail_service' do
    let(:mock_service) { instance_double(Google::Apis::GmailV1::GmailService) }

    before do
      allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(mock_service)
      allow(mock_service).to receive(:authorization=)
    end

    context 'when token is not expired' do
      before do
        gmail.update!(expires_at: 1.hour.from_now)
      end

      it 'returns gmail service without refreshing token' do
        expect(gmail).not_to receive(:refresh_token!)

        service = gmail.gmail_service

        expect(service).to eq(mock_service)
        expect(mock_service).to have_received(:authorization=).with(gmail.access_token)
      end
    end

    context 'when token is expired' do
      before do
        gmail.update!(expires_at: 1.hour.ago)
        allow(gmail).to receive(:refresh_token!).and_return(true)
      end

      it 'refreshes token before returning service' do
        expect(gmail).to receive(:refresh_token!)

        service = gmail.gmail_service

        expect(service).to eq(mock_service)
      end
    end
  end

  describe '#revoke_access' do
    before do
      gmail.update!(
        active: true,
        access_token: 'token',
        refresh_token: 'refresh',
        expires_at: 1.hour.from_now
      )
    end

    it 'deactivates the integration and clears tokens' do
      gmail.revoke_access

      gmail.reload
      expect(gmail.active).to be false
      expect(gmail.access_token).to be_nil
      expect(gmail.refresh_token).to be_nil
      expect(gmail.expires_at).to be_nil
    end
  end
end
