namespace :solid_queue do
  desc "Clear finished Solid Queue jobs (run hourly from the Heroku Scheduler)"
  task clear_finished: :environment do
    $stdout.sync = true
    before = SolidQueue::Job.count
    SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
    after = SolidQueue::Job.count
    puts "[solid_queue:clear_finished] #{before - after} cleared, #{after} remain"
  end
end
