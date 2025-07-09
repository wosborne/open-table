require 'rails_helper'

RSpec.describe InventoryUnit, type: :model do
  let(:variant) { create(:variant) }

  it "has a valid factory" do
    expect(build(:inventory_unit, variant: variant, serial_number: "SN123")).to be_valid
  end

  it "requires a serial_number" do
    unit = build(:inventory_unit, serial_number: nil, variant: variant)
    expect(unit).not_to be_valid
    expect(unit.errors[:serial_number]).to be_present
  end

  it "requires a unique serial_number" do
    create(:inventory_unit, serial_number: "SN123", variant: variant)
    unit = build(:inventory_unit, serial_number: "SN123", variant: variant)
    expect(unit).not_to be_valid
    expect(unit.errors[:serial_number]).to include("has already been taken")
  end

  it "belongs to a variant" do
    unit = build(:inventory_unit, variant: variant)
    expect(unit.variant).to eq(variant)
  end

  it "defines status enum" do
    unit = build(:inventory_unit, status: :in_stock, variant: variant)
    expect(unit).to be_in_stock
    unit.status = :sold
    expect(unit).to be_sold
  end

  it "scopes in_stock units" do
    in_stock = create(:inventory_unit, status: :in_stock, variant: variant, serial_number: "SN1")
    sold = create(:inventory_unit, status: :sold, variant: variant, serial_number: "SN2")
    expect(InventoryUnit.in_stock).to include(in_stock)
    expect(InventoryUnit.in_stock).not_to include(sold)
  end
end
