namespace :cache do
  desc "Warm the /items page cache (call from Heroku Scheduler every 10 min)"
  task warm_items: :environment do
    # Unbuffered so partial progress survives a crash. A previous run logged
    # nothing at all between "Starting process" and the scheduler dyno going
    # away, which buffered output would explain.
    $stdout.sync = true

    # The source filter is part of the fragment cache key, so warming only the
    # unfiltered page leaves "Brought only" / "Given only" cold on first hit.
    variants = [nil, "brought", "given"]
    overall  = Time.current

    variants.each do |source|
      started = Time.current
      attrs   = { controller: "items", action: "index" }
      attrs[:source] = source if source

      controller = ItemsController.new
      controller.action_name = "index"
      controller.params      = ActionController::Parameters.new(attrs)
      controller.send(:index)

      log "[cache:warm_items] #{source || 'all'} warmed in #{ms_since(started)}ms"
    rescue StandardError => e
      # One failing variant should not stop the others from warming.
      log "[cache:warm_items] #{source || 'all'} FAILED: #{e.class} #{e.message}"
    end

    log "[cache:warm_items] done in #{ms_since(overall)}ms"
  end

  def ms_since(t) = ((Time.current - t) * 1000).round

  def log(msg)
    Rails.logger.info msg
    puts msg
  end
end
