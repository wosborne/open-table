class MarketplaceController < ApplicationController
  def index
    @items = Item.joins(:table)
                 .where(table: { type: "InventoryTable" })
  end
end
