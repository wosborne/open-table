class Table < ApplicationRecord
  extend FriendlyId

  belongs_to :account
  has_many :items, dependent: :destroy
  has_many :limited_items, -> { limit(100) }, class_name: "Item"
  has_many :properties, dependent: :destroy

  has_one_attached :import

  after_create_commit :process_import_file

  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

  private

  def process_import_file
    Tables::ProcessImportCsv.call(self) if import.attached?
  end
end
