require "test_helper"

class AuthMailerTest < ActionMailer::TestCase
  test "the signup notice goes to the site contact with the useful details" do
    user = User.create!(email_address: "newbie@example.com", username: "newbie",
                        password: "password1")
    mail = AuthMailer.new_signup(user)

    assert_equal [ENV.fetch("CONTACT_EMAIL", "brad@nakedandafraidfan.com")], mail.to
    # Whatever MAILER_FROM resolves to in this environment — the point is it
    # inherits ApplicationMailer rather than hardcoding an address.
    assert_equal [ApplicationMailer.default[:from]], mail.from
    assert_match "newbie", mail.subject
    # Multipart: read the rendered parts, not the container.
    body = [mail.text_part&.decoded, mail.html_part&.decoded].compact.join("\n")
    assert_match "newbie@example.com", body
    assert_match(/not yet/, body, "an unverified signup should say so")
  end

  test "a member with no username still produces a sendable notice" do
    user = User.create!(email_address: "anon@example.com", password: "password1")
    mail = AuthMailer.new_signup(user)
    assert_match "anon@example.com", mail.subject
    assert_nothing_raised { [mail.text_part&.decoded, mail.html_part&.decoded] }
  end
end
