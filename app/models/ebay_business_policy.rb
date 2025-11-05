class EbayBusinessPolicy < ApplicationRecord
  POLICY_TYPES = %w[fulfillment payment return].freeze
  
  belongs_to :external_account
  
  validates :policy_type, presence: true, inclusion: { in: POLICY_TYPES }
  validates :ebay_policy_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :marketplace_id, presence: true
  
  scope :fulfillment, -> { where(policy_type: 'fulfillment') }
  scope :payment, -> { where(policy_type: 'payment') }
  scope :return, -> { where(policy_type: 'return') }
  
  def fulfillment?
    policy_type == 'fulfillment'
  end
  
  def payment?
    policy_type == 'payment'
  end
  
  def return?
    policy_type == 'return'
  end
end