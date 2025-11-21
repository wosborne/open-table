class Account < ApplicationRecord
  extend FriendlyId

  has_many :products, dependent: :destroy
  has_many :variants, through: :products
  has_many :inventory_units, dependent: :destroy
  has_many :locations, dependent: :destroy

  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users

  has_many :tables, dependent: :destroy

  has_many :external_accounts, dependent: :destroy
  has_one :shopify_account, -> { where(service_name: "shopify") }, class_name: "ExternalAccount"
  has_one :ebay_account, -> { where(service_name: "ebay") }, class_name: "ExternalAccount"

  has_many :notifications, as: :recipient, class_name: "Noticed::Notification", dependent: :destroy


  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  friendly_id :slug, use: :slugged
end
