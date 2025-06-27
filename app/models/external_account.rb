class ExternalAccount < ApplicationRecord
  SERVICE_NAMES = %w[shopify].freeze
  belongs_to :account

  validates :service_name, presence: true, uniqueness: { scope: :account_id }
  validates :service_name, inclusion: { in: SERVICE_NAMES }
  validates :api_token, presence: true
end