require "test_helper"

class LinkifySurvivorsTest < ActionView::TestCase
  include ApplicationHelper

  def survivor(name)
    Survivor.create!(full_name: name)
  end

  test "a full name links to its survivor" do
    a = survivor("Alice Ward")
    html = linkify_survivors("Alice Ward arrived.", [a])
    assert_includes html, %(href="#{survivor_path(a)}")
  end

  test "a surname shared by two cast members links neither" do
    a = survivor("Alice Ward")
    b = survivor("Bruce Ward")
    html = linkify_survivors("Ward was rescued.", [a, b])
    assert_no_match(/<a [^>]*>Ward</, html)
  end

  test "a unique surname links when capitalised as a name" do
    a = survivor("Alice Ward")
    b = survivor("Bruce Stone")
    html = linkify_survivors("Ward was rescued.", [a, b])
    assert_includes html, %(href="#{survivor_path(a)}")
  end

  test "an ordinary word that happens to be a surname is not linked" do
    a = survivor("Alice Short")
    b = survivor("Bruce Stone")
    html = linkify_survivors("They fell short of the goal.", [a, b])
    assert_no_match(/<a /, html)
  end

  test "a generational suffix is never used as the surname alias" do
    a = survivor("Steven Hall Jr")
    b = survivor("Bruce Stone")
    html = linkify_survivors("Jr is not a person.", [a, b])
    assert_no_match(/<a /, html)

    html = linkify_survivors("Hall found water.", [a, b])
    assert_includes html, %(href="#{survivor_path(a)}")
  end

  test "text is HTML-escaped" do
    a = survivor("Alice Ward")
    html = linkify_survivors("<script>x</script> Alice Ward", [a])
    assert_no_match(/<script>/, html)
  end
end
