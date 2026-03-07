class PageViewPingsController < ApplicationController
  MAX_DURATION = 1800 # 30 minutes cap

  skip_forgery_protection only: :create
  skip_after_action :record_page_view

  def create
    pv = PageView.find_by(id: params[:page_view_id])
    if pv
      seconds = [params[:seconds].to_i, MAX_DURATION].min
      pv.update_column(:duration_seconds, seconds) if seconds > 0
    end
    head :no_content
  end
end
