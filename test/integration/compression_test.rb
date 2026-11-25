require "test_helper"
require "zlib"
require "stringio"

class CompressionTest < ActionDispatch::IntegrationTest
  GZIP = { "Accept-Encoding" => "gzip" }.freeze

  def gunzip(body)
    Zlib::GzipReader.new(StringIO.new(body)).read
  end

  test "HTML pages are gzipped when the client accepts gzip" do
    get "/", headers: GZIP
    assert_response :success
    assert_equal "gzip", response.headers["Content-Encoding"]
    assert_match(/Accept-Encoding/i, response.headers["Vary"].to_s)
    assert_match(/<html/i, gunzip(response.body))
  end

  test "the sitemap is gzipped" do
    get "/sitemap.xml", headers: GZIP
    assert_response :success
    assert_equal "gzip", response.headers["Content-Encoding"]
    assert_equal "urlset", Nokogiri::XML(gunzip(response.body)).root.name
  end

  test "responses are not compressed when the client does not ask" do
    get "/"
    assert_response :success
    assert_nil response.headers["Content-Encoding"]
    assert_match(/<html/i, response.body)
  end

  test "redirects keep working (and carry no body worth compressing)" do
    get "/sitemap1.xml", headers: GZIP
    assert_response :moved_permanently
    assert_equal "http://www.example.com/sitemap.xml", response.headers["Location"]
  end

  test "conditional GETs still return 304 and are not compressed" do
    # The sitemap body is deterministic (the home page embeds a per-request CSP nonce).
    get "/sitemap.xml", headers: GZIP
    etag = response.headers["ETag"]
    assert etag.present?, "expected an ETag"

    get "/sitemap.xml", headers: GZIP.merge("If-None-Match" => etag)
    assert_response :not_modified
    assert_nil response.headers["Content-Encoding"]
  end

  # --- the compress? predicate in isolation ---

  def compress?(type, status: 200, extra: {})
    NandaCompression.compress?({}, status, { "content-type" => type }.merge(extra), [])
  end

  test "text-like types are compressible" do
    [ "text/html; charset=utf-8", "text/css", "text/javascript", "text/plain", "application/json",
      "application/javascript", "application/xml", "application/atom+xml", "application/rss+xml",
      "image/svg+xml", "application/manifest+json" ].each do |t|
      assert compress?(t), "expected #{t} to be compressed"
    end
  end

  test "already-compressed and streaming types are left alone" do
    [ "image/png", "image/jpeg", "image/webp", "image/avif", "video/mp4", "application/pdf",
      "application/zip", "font/woff2", "text/event-stream" ].each do |t|
      assert_not compress?(t), "expected #{t} NOT to be compressed"
    end
  end

  test "partial content responses are not compressed" do
    assert_not compress?("text/css", status: 206)
    assert_not compress?("text/css", extra: { "content-range" => "bytes 0-9/100" })
  end
end
