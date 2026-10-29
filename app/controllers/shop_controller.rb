# Public catalog of buyable Naked and Afraid gear (config/shop_products.yml).
class ShopController < ApplicationController
  def index
    all = ShopCatalog.products

    @q        = params[:q].to_s.strip.first(100)
    @category = params[:category].to_s
    @match    = params[:match].to_s
    @amazon   = params[:amazon] == "1"

    @categories   = all.map { |p| p[:category] }.compact.uniq.sort
    @total        = all.size
    @amazon_total = all.count { |p| ShopCatalog.amazon_link(p) }

    @products = all.select do |p|
      (@category.blank? || p[:category] == @category) &&
        (@match.blank? || p[:match] == @match) &&
        (!@amazon || ShopCatalog.amazon_link(p)) &&
        (@q.blank? || [p[:product], p[:brand], p[:item], p[:used_by]].compact.join(" ").downcase.include?(@q.downcase))
    end

    # Group by category (gear first, books/merch last), strongest evidence first inside each.
    rank = ShopCatalog::MATCHES.each_with_index.to_h
    @grouped = @products.sort_by { |p| [rank.fetch(p[:match], 99), p[:product].to_s.downcase] }
                        .group_by { |p| p[:category] }
                        .sort_by { |cat, _| [ShopCatalog::NON_GEAR.index(cat) ? 1 : 0, cat.to_s] }

    names = @products.map { |p| p[:item].presence }.compact.uniq
    @items_by_name = Item.where(name: names).index_by { |i| i.name.downcase }
    @links = ShopLinks.build(@products)

    # Filtered and searched views are thin duplicates of the main page; keep them out of search results.
    @filtered = [@q, @category, @match].any?(&:present?) || @amazon
  end
end
