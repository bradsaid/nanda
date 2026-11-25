# Shared rules for every list that is really paginated with ?page=N, so they all
# behave the same way:
#
#   * No page param, or page=1 spelled out: page one, whose URL is the clean one.
#   * A page param that is not a plain integer >= 2 ("abc", "0", "-3", "01",
#     "1", "2.5", "page[]=1"): 301 to the same URL without it. Rails/Kaminari used
#     to quietly serve page 1 under all of these URLs, i.e. endless duplicates.
#   * A page past the last one: 404 through the app's normal not-found path
#     (page 1 of an empty list is NOT out of range: it renders the empty state).
#
# Typical use in an index action:
#
#   page = requested_page or return              # nil means a redirect was issued
#   @items = Kaminari.paginate_array(rows, total_count: n).page(page).per(per)
#   ensure_page_in_range!(page, @items.total_pages)
module Paginatable
  extend ActiveSupport::Concern

  # A plain positive integer without leading zeros or signs.
  PAGE_FORMAT = /\A[1-9]\d*\z/

  private

  # The validated page number (>= 1), or nil after redirecting to the clean URL.
  # Sets @page_number, which the canonical-URL helper reads: only pages that really
  # paginate (and only beyond page 1) keep ?page=N in the canonical and og:url.
  def requested_page
    raw = params[:page]
    if raw.nil?
      @page_number = 1
    elsif raw.is_a?(String) && raw.match?(PAGE_FORMAT) && raw != "1"
      @page_number = raw.to_i
    else
      redirect_to without_page_param_path, status: :moved_permanently
      return nil
    end
    @page_number
  end

  # 404 for a page beyond the last. Page 1 is always valid, however empty the list.
  def ensure_page_in_range!(page, total_pages)
    raise ActionController::RoutingError, "Not Found" if page > 1 && page > total_pages
  end

  # [limit, offset] for hand-built queries.
  def page_window(page, per)
    [per, (page - 1) * per]
  end

  def total_pages_for(total_count, per)
    [(total_count.to_f / per).ceil, 1].max
  end

  # Same path and query string minus page.
  def without_page_param_path
    rest = request.query_parameters.except("page")
    rest.empty? ? request.path : "#{request.path}?#{rest.to_query}"
  end
end
