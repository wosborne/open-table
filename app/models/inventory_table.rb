class InventoryTable < Table
  before_destroy :prevent_destroy

  after_create :create_id_property

  private

  def prevent_destroy
    errors.add(:base, "Cannot delete the products table.")
    throw(:abort)
  end

  def create_id_property
    properties.create(name: "ID", type: "Properties::IdProperty")
  end
end
