require "test_helper"

class TrackPageViewsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  BROWSER_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  def visit(ip: "8.8.8.8", ua: BROWSER_UA)
    get root_path, headers: { "REMOTE_ADDR" => ip, "HTTP_USER_AGENT" => ua }
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
end
