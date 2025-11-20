require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:account) { create(:account) }
  let(:external_account) { create(:external_account, account: account) }
  let(:order) { create(:order, external_account: external_account) }

  describe 'associations' do
    it 'belongs to account' do
      notification = build(:notification)
      expect(notification).to respond_to(:account)
      expect(notification.account).to be_present
    end

    it 'belongs to notifiable optionally' do
      notification = build(:notification)
      expect(notification).to respond_to(:notifiable)
      expect(notification.notifiable).to be_nil
    end

    it 'can be associated with an order' do
      notification = create(:notification, account: account, notifiable: order)
      expect(notification.notifiable).to eq(order)
      expect(notification.notifiable_type).to eq('Order')
    end

    it 'can exist without a notifiable object' do
      notification = create(:notification, account: account, notifiable: nil)
      expect(notification.notifiable).to be_nil
    end
  end

  describe 'validations' do
    it 'validates presence of source' do
      notification = build(:notification, source: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:source]).to include("can't be blank")
    end

    it 'validates presence of notification_type' do
      notification = build(:notification, notification_type: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:notification_type]).to include("can't be blank")
    end

    it 'validates presence of title' do
      notification = build(:notification, title: nil)
      expect(notification).not_to be_valid
      expect(notification.errors[:title]).to include("can't be blank")
    end

    it 'allows notifications without message' do
      notification = build(:notification, account: account, message: nil)
      expect(notification).to be_valid
    end

    it 'allows notifications without external_id' do
      notification = build(:notification, account: account, external_id: nil)
      expect(notification).to be_valid
    end
  end

  describe 'scopes' do
    let!(:read_notification) { create(:notification, account: account, read: true) }
    let!(:unread_notification) { create(:notification, account: account, read: false) }
    let!(:processed_notification) { create(:notification, account: account, processed: true) }
    let!(:unprocessed_notification) { create(:notification, account: account, processed: false) }
    let!(:ebay_notification) { create(:notification, account: account, source: 'ebay') }
    let!(:shopify_notification) { create(:notification, account: account, source: 'shopify') }

    describe '.unread' do
      it 'returns only unread notifications' do
        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe '.read' do
      it 'returns only read notifications' do
        expect(Notification.read).to include(read_notification)
        expect(Notification.read).not_to include(unread_notification)
      end
    end

    describe '.processed' do
      it 'returns only processed notifications' do
        expect(Notification.processed).to include(processed_notification)
        expect(Notification.processed).not_to include(unprocessed_notification)
      end
    end

    describe '.unprocessed' do
      it 'returns only unprocessed notifications' do
        expect(Notification.unprocessed).to include(unprocessed_notification)
        expect(Notification.unprocessed).not_to include(processed_notification)
      end
    end

    describe '.by_source' do
      it 'returns notifications from specified source' do
        expect(Notification.by_source('ebay')).to include(ebay_notification)
        expect(Notification.by_source('ebay')).not_to include(shopify_notification)

        expect(Notification.by_source('shopify')).to include(shopify_notification)
        expect(Notification.by_source('shopify')).not_to include(ebay_notification)
      end
    end

    describe '.recent' do
      let!(:older_notification) { create(:notification, account: account, created_at: 2.days.ago) }
      let!(:newer_notification) { create(:notification, account: account, created_at: 1.day.ago) }

      it 'returns notifications in descending order by created_at' do
        recent_notifications = Notification.recent.limit(2)
        expect(recent_notifications.first.created_at).to be > recent_notifications.second.created_at
      end
    end
  end

  describe 'instance methods' do
    let(:notification) { create(:notification, account: account, read: false, processed: false) }

    describe '#mark_as_read!' do
      it 'marks notification as read' do
        expect { notification.mark_as_read! }.to change(notification, :read).from(false).to(true)
      end

      it 'persists the change' do
        notification.mark_as_read!
        expect(notification.reload.read).to be true
      end

      it 'raises error if update fails' do
        allow(notification).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(notification))
        expect { notification.mark_as_read! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '#mark_as_processed!' do
      it 'marks notification as processed' do
        expect { notification.mark_as_processed! }.to change(notification, :processed).from(false).to(true)
      end

      it 'persists the change' do
        notification.mark_as_processed!
        expect(notification.reload.processed).to be true
      end

      it 'raises error if update fails' do
        allow(notification).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(notification))
        expect { notification.mark_as_processed! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'polymorphic association behavior' do
    it 'can be associated with different model types' do
      order_notification = create(:notification, account: account, notifiable: order)
      # If you had other models like Product, you could test those too

      expect(order_notification.notifiable).to eq(order)
      expect(order_notification.notifiable_type).to eq('Order')
      expect(order_notification.notifiable_id).to eq(order.id)
    end

    it 'maintains referential integrity' do
      notification = create(:notification, account: account, notifiable: order)
      order_id = order.id

      order.destroy
      notification.reload

      # The notification should still exist but the notifiable should be nil
      expect(notification).to be_persisted
      expect(notification.notifiable).to be_nil
      expect(notification.notifiable_id).to eq(order_id) # ID remains but object is nil
    end
  end

  describe 'default values' do
    it 'sets default values correctly' do
      notification = Notification.new(
        account: account,
        source: 'test',
        notification_type: 'test_type',
        title: 'Test Title'
      )

      expect(notification.read).to be false
      expect(notification.processed).to be false
    end
  end
end
