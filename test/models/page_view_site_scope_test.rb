require "test_helper"

class PageViewSiteScopeTest < ActiveSupport::TestCase
  def view(path:, forum:, referrer_domain: nil, device_type: "Desktop")
    PageView.create!(path: path, controller_name: "x", action_name: "y", method: "GET",
                     ip_address: "8.8.8.8", forum: forum, referrer_domain: referrer_domain,
                     device_type: device_type, duration_seconds: 30)
  end

  test "direct counts views with no referrer and leaves out internal navigation" do
    none     = view(path: "/a", forum: false)
    internal = view(path: "/b", forum: false, referrer_domain: "nakedandafraidfan.com")
    assert_includes PageView.direct, none
    assert_not_includes PageView.direct, internal
  end

  test "dashboard figures built from the site scope exclude forum traffic" do
    view(path: "/a", forum: false, device_type: "Desktop")
    view(path: "/forum/x", forum: true, device_type: "Mobile")

    assert_equal({ "Desktop" => 1 }, PageView.site.device_breakdown)
    assert_equal 1, PageView.site.direct.count
    assert_equal ["/a"], PageView.site.avg_duration_by_page(10).map(&:path)
    assert_equal ["/a"], PageView.site.recent(10).map(&:path)
  end
end
