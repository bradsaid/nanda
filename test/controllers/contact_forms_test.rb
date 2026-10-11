require "test_helper"

class ContactFormsTest < ActionDispatch::IntegrationTest
  UA = { "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64) Chrome/140.0" }.freeze

  test "a normal contact message is sent" do
    assert_emails 1 do
      post contact_submit_path, params: { name: "Pat", email: "pat@example.com", message: "Hello" }, headers: UA
    end
  end

  test "an enormous message is refused" do
    assert_no_emails do
      post contact_submit_path, params: { name: "Pat", email: "pat@example.com", message: "x" * 6_000 }, headers: UA
    end
    assert_match(/too long/i, flash[:alert])
  end

  test "a bio submission with a non-image attachment is refused" do
    file = Rack::Test::UploadedFile.new(StringIO.new("MZ not a photo"), "application/x-msdownload", original_filename: "photo.exe")
    assert_no_emails do
      post submit_survivor_path(survivors(:one)),
           params: { name: "Pat", email: "pat@example.com", message: "Hello", photo: file }, headers: UA
    end
    assert_match(/jpeg, png, gif or webp/i, flash[:alert])
  end

  test "a bio submission with a photo is sent" do
    file = Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF fake jpeg"), "image/jpeg", original_filename: "photo.jpg")
    assert_emails 1 do
      post submit_survivor_path(survivors(:one)),
           params: { name: "Pat", email: "pat@example.com", message: "Hello", photo: file }, headers: UA
    end
  end

  test "the rack-attack rule limits both forms to five an hour per address" do
    was_enabled = Rack::Attack.enabled
    was_store   = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    begin
      5.times { post contact_submit_path, params: { name: "P", email: "p@example.com", message: "hi" }, headers: UA }
      assert_not_equal 429, response.status

      post contact_submit_path, params: { name: "P", email: "p@example.com", message: "hi" }, headers: UA
      assert_response 429

      # The bio form shares the budget for this address.
      post submit_survivor_path(survivors(:one)), params: { name: "P", email: "p@example.com", message: "hi" }, headers: UA
      assert_response 429
    ensure
      Rack::Attack.enabled = was_enabled
      Rack::Attack.cache.store = was_store
    end
  end
end
