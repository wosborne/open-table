class RootController < ApplicationController
  def index
    @tables = Table.all
  end
end
