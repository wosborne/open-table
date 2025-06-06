class ViewProperty < ApplicationRecord
  include Positionable

  belongs_to :view
  belongs_to :property

  scope :visible, -> { where(visible: true) }
  scope :hidden, -> { where(visible: false) }

  private

  def set_position
    self.position = view.view_properties.count
  end
end
