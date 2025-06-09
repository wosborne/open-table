class Account < ApplicationRecord
  extend FriendlyId

  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users

  has_many :tables, dependent: :destroy
  has_one :inventory_table, -> { where(type: "InventoryTable") }, class_name: "Table"

  has_many :tables, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  friendly_id :slug, use: :slugged

  after_create :create_inventory_table

  private

  def create_inventory_table
    tables.create(name: "Inventory", type: "InventoryTable")
  end
end
