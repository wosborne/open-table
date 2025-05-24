class PropertyOption < ApplicationRecord
  belongs_to :property

  validates :value, presence: true
  validates :value, uniqueness: { scope: :property_id }
end
