require "test_helper"

class TrackPageViewsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  include ActiveSupport::Testing::TimeHelpers

  # The test environment's cache is a null store, which would make every
  # reload look new.
  setup do
    @was_cache  = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @was_cache }

  def visit(ip: "8.8.8.8", ua: BROWSER_UA, path: root_path)
    get path, headers: { "REMOTE_ADDR" => ip, "HTTP_USER_AGENT" => ua }
  end

  test "a page view is recorded without blocking on geocoding" do
    assert_difference "PageView.count", 1 do
      assert_enqueued_with(job: GeocodePageViewJob) { visit }
    end
    pv = PageView.order(:id).last
    assert_equal "8.8.8.8", pv.ip_address
    # Geo is deliberately absent at request time — the job fills it in later.
    assert_nil pv.country
    assert_nil pv.city
  end

  test "no geocoding job is queued for a loopback address" do
    assert_no_enqueued_jobs(only: GeocodePageViewJob) do
      visit(ip: "127.0.0.1")
    end
  end

  test "bots are not tracked and queue no geocoding" do
    assert_no_difference "PageView.count" do
      assert_no_enqueued_jobs(only: GeocodePageViewJob) do
        visit(ua: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
      end
    end
  end

  test "a reload of the same page moments later is not a new view" do
    assert_difference "PageView.count", 1 do
      assert_enqueued_jobs(1, only: GeocodePageViewJob) do
        5.times { visit }
      end
    end
  end

  test "a reload reports back against the view it repeats" do
    visit
    first_id = PageView.order(:id).last.id.to_s
    visit
    assert_equal first_id, @response.headers["X-Page-View-Id"]
  end

  test "coming back to a page after a while is a new view" do
    visit
    travel 31.seconds do
      assert_difference("PageView.count", 1) { visit }
    end
  end

  test "different pages, or a different visitor, are each counted" do
    visit
    assert_difference("PageView.count", 1) { visit(path: "/episodes") }
    assert_difference("PageView.count", 1) { visit(path: "/episodes?page=2") }
    assert_difference("PageView.count", 1) { visit(ip: "9.9.9.9") }
  end
end
