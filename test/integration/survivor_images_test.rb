require "test_helper"
require "delegate"
require "minitest/mock"

# Survivor avatars on the home page and the survivor index/show pages use Active Storage's
# PROXY route (stable, cacheable URL) instead of the redirect route (302 to a short-lived
# signed S3 URL), at WebP variants with explicit dimensions and the right loading hints.
#
# libvips is not required here: building a variant URL does not process the image.
class SurvivorImagesTest < ActionDispatch::IntegrationTest
  # 1x1 PNG
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  # Lets a representation-proxy request run without libvips: the "representation" is the
  # original blob (which can be downloaded and streamed) and #processed is a no-op.
  module UnprocessedRepresentation
    class Fake < SimpleDelegator
      def processed = self
    end

    class << self
      attr_accessor :enabled
    end

    def representation(*args)
      UnprocessedRepresentation.enabled ? Fake.new(self) : super
    end
  end
  ActiveStorage::Blob.prepend(UnprocessedRepresentation)

  setup do
    @a = survivors(:one)
    @b = survivors(:two)
    [ @a, @b ].each { |s| s.avatar.attach(io: StringIO.new(PNG), filename: "face.png", content_type: "image/png") }
  end

  teardown { UnprocessedRepresentation.enabled = false }

  # The variation key in /rails/active_storage/representations/proxy/<blob>/<variation>/<file>.
  def variation_format(src)
    ActiveStorage::Variation.decode(src.split("/")[6]).format.to_s
  end

  # A real view context (url helpers included), unlike ApplicationController.helpers.
  def view
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.view_context
  end

  def avatars(path)
    get path
    assert_response :success
    Nokogiri::HTML(response.body).css("img.avatar-portrait, img.avatar-lg")
  end

  def assert_proxy_avatar(img, width:, height:)
    assert_match %r{\A/rails/active_storage/representations/proxy/}, img["src"], "avatar must use the proxy route"
    assert_equal "webp", variation_format(img["src"])
    assert_no_match %r{/redirect/|/rails/active_storage/blobs/redirect}, img["src"]
    assert_equal width.to_s,  img["width"]
    assert_equal height.to_s, img["height"]
    assert_equal "async", img["decoding"]
  end

  test "home page avatars are proxied WebP thumbs with explicit size and lazy loading" do
    imgs = avatars("/")
    assert_operator imgs.size, :>=, 2
    imgs.each do |img|
      assert_proxy_avatar(img, width: 130, height: 170)
      assert_equal "lazy", img["loading"], "no below-the-fold avatar may be eager"
      assert_nil img["fetchpriority"]
    end
  end

  test "home page has no redirect-mode Active Storage URLs" do
    get "/"
    assert_no_match %r{active_storage/(blobs|representations)/redirect}, response.body
  end

  test "the survivors index uses the same proxied thumbs" do
    imgs = avatars("/survivors")
    assert_operator imgs.size, :>=, 2
    imgs.each do |img|
      assert_proxy_avatar(img, width: 130, height: 170)
      assert_equal "lazy", img["loading"]
    end
  end

  test "the survivor page headshot is a proxied 160x160 WebP, eager and high priority" do
    imgs = avatars(survivor_path(@a))
    img = imgs.find { |i| i["class"].to_s.include?("avatar-lg") }
    assert img, "expected the .avatar-lg headshot"
    assert_proxy_avatar(img, width: 160, height: 160)
    assert_equal "eager", img["loading"]
    assert_equal "high", img["fetchpriority"]
  end

  test "avatar URLs are stable between requests (no expiring signature)" do
    first  = avatars("/survivors").map { |i| i["src"] }.sort
    second = avatars("/survivors").map { |i| i["src"] }.sort
    assert_equal first, second
    assert_equal first.uniq.size, first.size
  end

  test "survivors without an avatar keep the initials placeholder" do
    @a.avatar.purge
    src = view.avatar_src(@a.reload, name: @a.full_name)
    assert_match(/\Adata:image\/svg\+xml/, src)
  end

  test "avatar_src falls back to the proxied original when the variant cannot be built" do
    src = view.avatar_src(@a, name: @a.full_name, variant: :no_such_variant)
    assert_match %r{\A/rails/active_storage/blobs/proxy/}, src
  end

  test "avatar_src falls back to the initials SVG if even the proxy URL cannot be built" do
    helper = view
    helper.stub(:rails_storage_proxy_path, ->(*) { raise ArgumentError, "boom" }) do
      assert_match(/\Adata:image\/svg\+xml/, helper.avatar_src(@a, name: @a.full_name))
    end
  end

  test "variants are WebP at 2x the displayed size" do
    variants = Survivor.reflect_on_attachment(:avatar).named_variants
    assert_equal [ 260, 340 ], variants[:thumb].transformations[:resize_to_fill]
    assert_equal [ 320, 320 ], variants[:profile].transformations[:resize_to_fill]
    %i[thumb portrait profile chip].each do |name|
      assert_equal :webp, variants[name].transformations[:format], "#{name} should be webp"
    end
  end

  test "blob proxy response is public, cached for years and immutable" do
    get rails_storage_proxy_path(@a.avatar, expires_in: nil)
    assert_response :success
    assert_cache_headers
  end

  test "representation proxy response is public, cached for years and immutable" do
    UnprocessedRepresentation.enabled = true
    path = rails_storage_proxy_path(@a.avatar.variant(:thumb), expires_in: nil)
    get path
    assert_response :success
    assert_cache_headers
  end

  def assert_cache_headers
    cc = response.headers["Cache-Control"].to_s
    assert_match(/\bpublic\b/, cc)
    assert_match(/\bimmutable\b/, cc)
    assert_operator cc[/max-age=(\d+)/, 1].to_i, :>=, 1.year.to_i
    assert_no_match(/\bprivate\b|no-cache|no-store/, cc)
  end
end
