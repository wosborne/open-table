require 'rails_helper'

RSpec.describe "InventoryUnits", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/inventory_units/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/inventory_units/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/inventory_units/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/inventory_units/show"
      expect(response).to have_http_status(:success)
    end
  end

end
