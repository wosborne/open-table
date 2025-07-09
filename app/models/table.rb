class Table < ApplicationRecord
  extend FriendlyId

  belongs_to :account
  has_many :records, dependent: :destroy
  has_many :limited_records, -> { limit(100) }, class_name: "Record"
  has_many :properties, dependent: :destroy
  has_many :views, -> { order(:position) }, dependent: :destroy

  has_one_attached :import

  after_create :create_initial_view
  after_create_commit :process_import_file

  friendly_id :name, use: :slugged

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

  private

  def create_initial_view
    views.create(name: "Everything")
  end

  def process_import_file
    Tables::ProcessImportCsv.call(self) if import.attached?
  end
end
