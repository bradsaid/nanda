# Gear guides: one public landing page per catalog category ("Knives, Machetes & Blades Used
# on Naked and Afraid"), built from config/shop_products.yml.
class ShopGuidesController < ApplicationController
  def index
    @guides = ShopCatalog.guides
    @counts = ShopCatalog.products.group_by { |p| p[:category].to_s }.transform_values(&:size)
  end

  def show
    @guide = ShopCatalog.guide(params[:slug])
    return render(plain: "Guide not found", status: :not_found) unless @guide

    rank = ShopCatalog::MATCHES.each_with_index.to_h
    list = ShopCatalog.products.select { |p| p[:category].to_s == @guide.category }
    # One section per item (A to Z); strongest evidence first inside each.
    @groups = list.group_by { |p| p[:item].to_s }
                  .sort_by { |item, _| item.downcase }
                  .map { |item, ps| [item, ps.sort_by { |p| [rank.fetch(p[:match], 99), p[:product].to_s.downcase] }] }
    @products = @groups.flat_map(&:last)
    @items_by_name = Item.where("LOWER(name) IN (?)", @groups.map { |name, _| name.downcase }).index_by { |i| i.name.downcase }
    @links = ShopLinks.build(@products)
    @other_guides = ShopCatalog.guides.reject { |g| g.slug == @guide.slug }
  end
end
