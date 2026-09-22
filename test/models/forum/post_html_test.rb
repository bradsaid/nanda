require "test_helper"

# Posts may now contain raw HTML, which makes the sanitiser the only thing
# between a post and the page. These tests are the security boundary.
class Forum::PostHtmlTest < ActiveSupport::TestCase
  setup do
    @topic = Forum::Topic.create!(forum_category: forum_categories(:general),
                                  user: users(:one), title: "HTML in posts")
  end

  def rendered(body)
    @topic.posts.create!(user: users(:one), body: body).body_html.to_s
  end

  # --- what must now work -------------------------------------------------
  test "basic formatting tags survive" do
    html = rendered("<b>bold</b> and <i>italic</i> and <u>under</u>")
    assert_includes html, "<b>bold</b>"
    assert_includes html, "<i>italic</i>"
    assert_includes html, "<u>under</u>"
  end

  test "headings, lists and tables survive" do
    html = rendered("<h3>Heading</h3><ul><li>one</li></ul><table><tr><td>cell</td></tr></table>")
    assert_includes html, "<h3>Heading</h3>"
    assert_includes html, "<li>one</li>"
    assert_includes html, "<td>cell</td>"
  end

  test "an image with a normal source survives" do
    assert_includes rendered(%(<img src="https://example.com/a.png" alt="a">)), "https://example.com/a.png"
  end

  test "markdown still works alongside html" do
    html = rendered("**strong** and <em>tag</em>")
    assert_includes html, "<strong>strong</strong>"
    assert_includes html, "<em>tag</em>"
  end

  # --- what must still be impossible --------------------------------------
  test "script tags never reach the page as executable markup" do
    html = rendered("<script>alert('x')</script>hello")
    # No live tag. The markup is escaped instead, so it renders as visible
    # text rather than running — safe, and the author can see it did nothing.
    assert_not_includes html, "<script"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "hello"
  end

  test "event handler attributes are stripped" do
    html = rendered(%(<img src="x" onerror="alert(1)"><b onclick="alert(2)">hi</b>))
    assert_not_includes html, "onerror"
    assert_not_includes html, "onclick"
  end

  test "javascript: urls are stripped from links and images" do
    html = rendered(%([click](javascript:alert(1)) <a href="javascript:alert(2)">x</a> <img src="javascript:alert(3)">))
    assert_not_includes html, "javascript:"
  end

  test "iframes, objects and embeds are removed" do
    html = rendered(%(<iframe src="https://evil.test"></iframe><object data="x"></object><embed src="y">))
    assert_not_includes html, "<iframe"
    assert_not_includes html, "<object"
    assert_not_includes html, "<embed"
  end

  test "style tags and style attributes are removed" do
    html = rendered(%(<style>body{display:none}</style><p style="position:fixed;top:0">x</p>))
    assert_not_includes html, "<style"
    assert_not_includes html, "style="
  end

  test "class and id are stripped so a post cannot borrow site layout" do
    html = rendered(%(<div class="position-fixed w-100" id="content">x</div>))
    assert_not_includes html, "class="
    assert_not_includes html, "id="
  end

  test "forms and inputs cannot be used to phish" do
    html = rendered(%(<form action="https://evil.test"><input name="password"></form>))
    assert_not_includes html, "<form"
    assert_not_includes html, "<input"
  end

  test "target is stripped so links cannot tabnab" do
    assert_not_includes rendered(%(<a href="https://example.com" target="_blank">x</a>)), "target="
  end
end
