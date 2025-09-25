module Admin
  class SeasonsController < Admin::ApplicationController
    def scoped_resource
      super.includes(:series).order("series.name ASC, seasons.number ASC")
    end
  end
end
