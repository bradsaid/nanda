require "test_helper"

class SurvivorsControllerTest < ActionDispatch::IntegrationTest
  test "the current slug renders" do
    get survivor_path(survivors(:one))
    assert_response :success
  end

  test "a numeric id still renders without redirecting" do
    get "/survivors/#{survivors(:one).id}"
    assert_response :success
  end

  test "an old slug 301s to the current one after a rename" do
    s = Survivor.create!(full_name: "Joesph Prouse")
    old_slug = s.slug
    s.update!(full_name: "Joseph Prouse")

    get "/survivors/#{old_slug}"

    assert_response :moved_permanently
    assert_redirected_to "/survivors/#{s.slug}"
  end

  test "an unknown slug is a 404, not a redirect" do
    get "/survivors/no-such-person"
    assert_response :not_found
  end
end
