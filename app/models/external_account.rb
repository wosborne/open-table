class ExternalAccount < ApplicationRecord
  SERVICE_NAMES = %w[shopify].freeze
  belongs_to :account

  has_many :external_account_products, dependent: :destroy

  validates :service_name, presence: true, uniqueness: { scope: :account_id }
  validates :service_name, inclusion: { in: SERVICE_NAMES }
  validates :api_token, presence: true
end
