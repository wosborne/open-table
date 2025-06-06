module Positionable
  extend ActiveSupport::Concern

  included do
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_position, on: :create
  end
end
