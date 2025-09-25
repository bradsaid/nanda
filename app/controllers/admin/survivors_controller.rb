module Admin
  class SurvivorsController < Admin::ApplicationController
    def scoped_resource
      super.order(:last_name, :first_name)
    end
  end
end
