class Account < ApplicationRecord
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users

  has_many :tables, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def to_param
    slug
  end
end
