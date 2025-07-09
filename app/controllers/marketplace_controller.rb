class MarketplaceController < ApplicationController
  def index
    @records = Record.joins(:table)
                 .where(table: { type: "InventoryTable" })
  end
end
