namespace :forum do
  # Temporary accounts for an external bot to exercise the forum while
  # FORUM_ENABLED is still unset. They use the forum_tester role, which grants
  # forum visibility and nothing else — no /admin, no moderation. All of them
  # sit on @grok.test so they are trivially identifiable and removable, and
  # kept distinct from the older @fan.test seed accounts.
  TESTER_COUNT  = 5
  TESTER_DOMAIN = "grok.test".freeze

  desc "Create #{5} temporary forum_tester accounts and print their credentials"
  task create_testers: :environment do
    require "securerandom"
    $stdout.sync = true

    rows = (1..TESTER_COUNT).map do |i|
      username = "grok_tester_#{i}"
      email    = "#{username}@#{TESTER_DOMAIN}"
      password = SecureRandom.alphanumeric(16)

      u = User.find_or_initialize_by(email_address: email)
      u.assign_attributes(
        username:              username,
        password:              password,
        password_confirmation: password,
        email_verified_at:     Time.current,  # forum writes require a verified account
        role:                  :forum_tester,
        bio:                   "Temporary account for forum testing."
      )
      u.save!
      [username, email, password]
    end

    puts
    puts "Created #{rows.size} forum_tester accounts. Passwords are shown ONCE —"
    puts "they are stored only as bcrypt digests and cannot be recovered later."
    puts
    puts format("%-16s %-28s %s", "USERNAME", "EMAIL", "PASSWORD")
    rows.each { |username, email, password| puts format("%-16s %-28s %s", username, email, password) }
    puts
    puts "Sign in at /session/new. These accounts can see and post in the forum"
    puts "while FORUM_ENABLED is unset, and can reach nothing else."
    puts "Remove them with: rails forum:remove_testers"
  end

  desc "Remove the temporary forum_tester accounts and everything they posted"
  task remove_testers: :environment do
    $stdout.sync = true
    testers = User.where("email_address LIKE ?", "%@#{TESTER_DOMAIN}")

    if testers.none?
      puts "No @#{TESTER_DOMAIN} accounts found; nothing to remove."
      next
    end

    topics = Forum::Topic.where(user_id: testers.select(:id)).count
    posts  = Forum::Post.where(user_id: testers.select(:id)).count
    puts "Removing #{testers.count} tester accounts, #{topics} topics and #{posts} posts..."

    # User has dependent: :destroy for topics/posts/subscriptions and
    # dependent: :nullify for last_post_user_id, so this cleans up after itself.
    testers.destroy_all
    puts "Done. Remaining forum_tester accounts: #{User.forum_tester.count}"
  end
end
