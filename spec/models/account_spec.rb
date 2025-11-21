require 'rails_helper'

RSpec.describe Account, type: :model do
  let(:account) { create(:account) }

  describe 'associations' do
    it { should have_one(:gmail) }
  end

  describe '#gmail_connected?' do
    context 'when account has no gmail integration' do
      it 'returns false' do
        expect(account.gmail_connected?).to be false
      end
    end

    context 'when account has inactive gmail integration' do
      before do
        create(:gmail, account: account, active: false)
      end

      it 'returns false' do
        expect(account.gmail_connected?).to be false
      end
    end

    context 'when account has active gmail integration' do
      before do
        create(:gmail, account: account, active: true)
      end

      it 'returns true' do
        expect(account.gmail_connected?).to be true
      end
    end
  end

  describe '#can_send_emails?' do
    context 'when gmail is not connected' do
      it 'returns false' do
        expect(account.can_send_emails?).to be false
      end
    end

    context 'when gmail is connected but token is expired' do
      before do
        create(:gmail, :expired, account: account)
      end

      it 'returns false' do
        expect(account.can_send_emails?).to be false
      end
    end

    context 'when gmail is connected and token is valid' do
      before do
        create(:gmail, account: account, expires_at: 1.hour.from_now)
      end

      it 'returns true' do
        expect(account.can_send_emails?).to be true
      end
    end
  end
end
