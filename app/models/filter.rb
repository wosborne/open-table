class Filter < ApplicationRecord
  belongs_to :view
  belongs_to :property

  validates :value, presence: true
end
