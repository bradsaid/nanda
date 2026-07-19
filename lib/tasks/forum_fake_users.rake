namespace :forum do
  # Fake users all use @fan.test emails and fan_ usernames so they're
  # trivial to wipe with `bin/rails forum:wipe_fake_users`. Every write here
  # is idempotent: rerunning replaces the seed set instead of piling on.
  desc "Seed 10 fake forum users with topics + replies + bios (idempotent)"
  task seed_fake_users: :environment do
    require "securerandom"

    FAKES = [
      { username: "fan_kate",     bio: "Been watching since S1. Love the desert episodes." },
      { username: "fan_marco",    bio: "Bushcraft nerd, machete over bow every day of the week." },
      { username: "fan_dana",     bio: "Season 20 changed my life. Ask me about tarps." },
      { username: "fan_rico",     bio: "I make firestarter for a living. Yes really." },
      { username: "fan_lulu",     bio: "Africa episodes only. Send me your Zambezi recaps." },
      { username: "fan_pete",     bio: "Casual viewer, deeply invested. RIP the alpaca." },
      { username: "fan_amara",    bio: "Marine biologist. I have OPINIONS about the water quality." },
      { username: "fan_sean",     bio: "XL season 6 fan for life." },
      { username: "fan_yuki",     bio: "Watching from Osaka. Subtitles by fan love." },
      { username: "fan_ben",      bio: "Ex-EMT. Medical tap outs make me nervous." }
    ]

    puts "Creating #{FAKES.size} fake users..."
    users = FAKES.map do |attrs|
      u = User.find_or_initialize_by(email_address: "#{attrs[:username]}@fan.test")
      u.assign_attributes(
        username: attrs[:username],
        bio:      attrs[:bio],
        password: "fakepass1", password_confirmation: "fakepass1",
        email_verified_at: Time.current,
        role: :user
      )
      u.save!
      u
    end
    puts "  users: #{users.map(&:username).join(', ')}"

    # Wipe old fake content so re-runs don't accumulate junk.
    fake_ids = users.map(&:id)
    Forum::Topic.where(user_id: fake_ids).destroy_all
    Forum::Post.where(user_id: fake_ids).destroy_all

    categories = Forum::Category.ordered.to_a
    raise "Seed forum categories first (bin/rails forum:seed)" if categories.empty?

    topic_seeds = [
      { cat: "general-discussion",     title: "First-time watcher — where do I start?",
        body: "Just finished the S1 premiere. Loved it. Any recommendations for the best 3 seasons to binge next? I like the ones where they actually complete the challenge." },
      { cat: "general-discussion",     title: "The prayer stick tradition — origin?",
        body: "Curious when the prayer stick tradition started. Was it in the *original* pilot, or did it come in around Season 2?" },
      { cat: "season-talk",            title: "Season 17 was underrated",
        body: "Hear me out. The pacing was slow but the character development was some of the best in the series. Who's with me?" },
      { cat: "season-talk",            title: "XL 10 predictions thread",
        body: "Dropping my early XL 10 predictions. Two survivalists tap in the first week. One medical evac around day 25. And someone brings a folding shovel that gets confiscated on day 1." },
      { cat: "meet-the-survivalists",  title: "Anyone know what Bo is up to these days?",
        body: "He was one of my favorites and just seemed to vanish. Any updates from anyone in the community?" },
      { cat: "meet-the-survivalists",  title: "Steven & Jenny Kelly appreciation post",
        body: "The couple that survives together, stays together. Genuinely the most functional partnership on the show." },
      { cat: "speculation-predictions", title: "Where should the next season film?",
        body: "I want to see a proper high-altitude Andes challenge. Real cold, real thin air, real consequences. Discovery, are you listening?" },
      { cat: "item-talk",              title: "Machete vs. bow-drill kit — pick one",
        body: "You get exactly one. Which do you take, and what's your reasoning?\n\nMe: **machete**. Nothing else lets you build shelter, defense, food processing, and firewood all with one tool." },
      { cat: "item-talk",              title: "Firestarter meta post",
        body: "Ferro rod is the obvious pick but I'm curious how many people would actually bring flint & steel. Anyone tried it in prep?" },
      { cat: "off-topic",              title: "What are you watching between seasons?",
        body: "Give me your favorite survival-adjacent shows. I've already done *Alone*, *Outlast*, and *Man vs. Wild*. What else?" }
    ]

    reply_pool = [
      "Great point.",
      "I hard disagree — that season had the worst pacing since S9.",
      "Not sure I've seen enough of the recent episodes to weigh in.",
      "This is exactly why I keep coming back to the show. Nothing else compares.",
      "You're forgetting the Zambia arc. That's the actual answer.",
      "Machete every time. But I get the case for the pot.",
      "Anyone else find the camera work in the last batch a bit rough?",
      "Rewatched last night. Holds up.",
      "I emailed the producers about this exact thing.",
      "Firestarter setup only works if you keep it dry. Half these people don't.",
      "Would love to hear a survivalist's actual take on this.",
      "The DB says otherwise — check the episode notes.",
      "Bringing this thread back from the dead but wow, prescient.",
      "Legit LOL at the mental image of that folding shovel getting confiscated.",
      "Fair. Convinced.",
      "The prayer stick showed up around S3 iirc — someone correct me."
    ]

    puts "Creating topics + replies..."
    created_topics = 0
    created_posts  = 0
    topic_seeds.each_with_index do |seed, idx|
      cat = categories.find { |c| c.slug == seed[:cat] } || categories.first
      author = users[idx % users.size]

      Forum::Topic.transaction do
        topic = cat.topics.create!(user: author, title: seed[:title])
        topic.posts.create!(user: author, body: seed[:body])
        created_topics += 1
        created_posts  += 1

        # 2..5 replies from other users
        reply_count = 2 + (idx % 4)
        (users - [author]).sample(reply_count).each do |commenter|
          body = reply_pool.sample
          topic.posts.create!(user: commenter, body: body)
          created_posts += 1
        end
      end
    end

    puts "  topics created:  #{created_topics}"
    puts "  posts created:   #{created_posts}"
    puts "Done."
  end

  desc "Wipe fake users + their forum content"
  task wipe_fake_users: :environment do
    fakes = User.where("email_address LIKE ?", "%@fan.test")
    puts "Wiping #{fakes.count} fake users and their content..."
    Forum::Topic.where(user_id: fakes.pluck(:id)).destroy_all
    Forum::Post.where(user_id: fakes.pluck(:id)).destroy_all
    fakes.destroy_all
    puts "Done."
  end
end
