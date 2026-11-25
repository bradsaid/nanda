# Permanent redirects from old URL spellings to the one slug URL, shared by every page
# whose URL is a slug: episodes and items (friendly_id, with history) and the name pages
# (countries, food sources, shelters, item types; see NameSlugs).
#
#   /episodes/123                   -> /episodes/naked-and-afraid-s14e2-haunted-and-hungry
#   /items/<an old slug>            -> /items/<the current slug>
#   /episodes/by_country/South%20Africa -> /episodes/by_country/south-africa
#
# The query string is kept (?page=2, ?country=...). Redirects are not recorded as page
# views: the visitor lands on the canonical URL next, which is the one that counts.
module SlugRedirects
  extend ActiveSupport::Concern

  private

  # Episode / Item by slug, old slug (history) or numeric id. A slug typed in capitals
  # ("/items/Fire-Starter") finds the record too, and then redirects to the lower-case URL.
  # Raises RecordNotFound (a 404) for anything else.
  def find_by_slug_or_id(scope, value)
    scope.friendly.find(value)
  rescue ActiveRecord::RecordNotFound
    lowered = value.to_s.downcase
    raise if lowered == value.to_s
    scope.friendly.find(lowered)
  end

  # After find_by_slug_or_id: if the URL used a numeric id, an old slug or another
  # spelling, send the visitor to the record's current URL. True when it redirected.
  def redirect_to_current_slug(record)
    return false if params[:id].to_s == record.to_param
    path = url_for(controller: controller_path, action: action_name, id: record.to_param,
                   format: params[:format], only_path: true)
    redirect_permanently(path)
    true
  end

  # Resolves the name segment (params[:country], ...) for a NameSlugs kind. Returns the
  # NameSlugs::Match when the URL is already the canonical slug. For an old spelling it
  # redirects to the block's path (given the slug) and returns nil; an unknown name is a
  # 404.
  def resolve_name_slug!(kind, segment)
    match = NameSlugs.resolve(kind, segment)
    raise ActiveRecord::RecordNotFound, "Unknown #{kind}: #{segment}" unless match
    return match if match.slug == segment.to_s
    redirect_permanently(yield(match.slug))
    nil
  end

  def redirect_permanently(path)
    path = "#{path}?#{request.query_string}" if request.query_string.present?
    @skip_page_view = true
    redirect_to path, status: :moved_permanently
  end
end
