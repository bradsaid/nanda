namespace :cache do
  desc "Warm the /items page cache (call from Heroku Scheduler every 10 min)"
  task warm_items: :environment do
    started = Time.current
    controller = ItemsController.new
    controller.action_name = "index"
    controller.params = ActionController::Parameters.new(
      controller: "items", action: "index"
    )
    controller.send(:index)
    elapsed_ms = ((Time.current - started) * 1000).round
    Rails.logger.info "[cache:warm_items] populated in #{elapsed_ms}ms"
    puts "[cache:warm_items] populated in #{elapsed_ms}ms"
  end
end
