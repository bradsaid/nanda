require "test_helper"

class Admin::DashboardRenderTest < ActionDispatch::IntegrationTest
  test "the dashboard renders with site and forum traffic present" do
    PageView.create!(path: "/a", controller_name: "x", action_name: "y", method: "GET",
                     ip_address: "8.8.8.8", forum: false, device_type: "Desktop", duration_seconds: 5)
    PageView.create!(path: "/forum/x", controller_name: "x", action_name: "y", method: "GET",
                     ip_address: "8.8.8.8", forum: true, device_type: "Mobile", duration_seconds: 5)

    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get admin_root_path
    assert_response :success
  end

  test "the views chart loads Chart.js from our own origin, not a CDN" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    get admin_root_path
    assert_response :success
    assert_match %r{<script[^>]+src="/assets/chart\.umd-[^"]+\.js"}, response.body
    assert_no_match(%r{cdn\.jsdelivr\.net/npm/chart\.js}, response.body)
    assert_select "canvas#admin-views-chart"
    assert_select "script#admin-views-chart-data"
  end
end
