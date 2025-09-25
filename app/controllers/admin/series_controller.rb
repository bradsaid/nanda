module Admin
  class SeriesController < Admin::ApplicationController
    def scoped_resource
      super.order(:name)
    end
  end
end
