class Order < ApplicationRecord
  belongs_to :external_account
  has_many :order_line_items, dependent: :destroy

  validates :external_account, :external_id, :currency, :total_price, :external_created_at, presence: true
  validates :external_id, uniqueness: { scope: :external_account_id }
end
