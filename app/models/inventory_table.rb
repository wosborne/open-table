class InventoryTable < Table
  before_destroy :prevent_destroy

  after_create :create_default_properties

  private

  def prevent_destroy
    errors.add(:base, "Cannot delete the products table.")
    throw(:abort)
  end

  def create_default_properties
    properties.create(name: "ID", type: "Properties::IdProperty", editable: false)
    properties.create(name: "Created at", type: "Properties::TimestampProperty", deletable: false, editable: false)
    properties.create(name: "Updated at", type: "Properties::TimestampProperty", deletable: false, editable: false)
    properties.create(name: "Marketplace", type: "Properties::CheckboxProperty", deletable: false, editable: false)
    properties.create(name: "Shopify", type: "Properties::ShopifyProperty", deletable: false, editable: false)
  end
end
