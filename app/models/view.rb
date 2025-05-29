class View < ApplicationRecord
  extend FriendlyId

  belongs_to :table
  has_many :filters, dependent: :destroy

  accepts_nested_attributes_for :filters, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :table_id, case_sensitive: false }

  friendly_id :name, use: :slugged

  def should_generate_new_friendly_id?
    name_changed?
  end
end
