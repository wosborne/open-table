class Table < ApplicationRecord
  belongs_to :account
  has_many :items, dependent: :destroy
  has_many :limited_items, -> { limit(100) }, class_name: "Item"
  has_many :properties, dependent: :destroy

  has_one_attached :import

  after_create_commit :process_import_file

  private

  def process_import_file
    Tables::ProcessImportCsv.call(self) if import.attached?
  end
end
