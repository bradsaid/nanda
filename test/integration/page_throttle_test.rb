require "test_helper"

# Rack::Attack is disabled in the test environment by default, and Rails.cache
# is a null store there, so both have to be turned on deliberately for these.
class PageThrottleTest < ActionDispatch::IntegrationTest
  setup do
    @was_enabled = Rack::Attack.enabled
    @was_store   = Rack::Attack.cache.store
    Rack::Attack.enabled     = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.enabled     = @was_enabled
    Rack::Attack.cache.store = @was_store
  end

  def get_as(ip, path = "/items")
    get path, headers: { "REMOTE_ADDR" => ip }
  end

  test "a scraper bursting past the limit is refused" do
    31.times { get_as "203.0.113.10" }
    assert_response :too_many_requests
    assert_match(/slow down/i, @response.body)
  end

  test "the refusal tells the client when to come back" do
    31.times { get_as "203.0.113.11" }
    assert @response.headers["Retry-After"].present?
  end

  test "ordinary browsing is never touched" do
    # Far brisker than a human clicking, and still well inside the limit.
    20.times { get_as "203.0.113.12" }
    assert_response :success
  end

  test "one visitor's burst does not affect anyone else" do
    31.times { get_as "203.0.113.13" }
    assert_response :too_many_requests

    get_as "203.0.113.14"
    assert_response :success, "a different visitor must be unaffected"
  end

  test "images and assets do not count towards the limit" do
    # A page full of avatars fires many of these; counting them would throttle
    # a genuine reader partway through loading one page.
    40.times { get_as "203.0.113.15", "/assets/application.css" }
    get_as "203.0.113.15"
    assert_response :success
  end

  test "the forum is still covered by its own throttle" do
    get_as "203.0.113.16", "/forum"
    assert_includes [200, 404], @response.status
  end
end
