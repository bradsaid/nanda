module ApplicationHelper
  def format_duration(seconds)
    return "—" if seconds.blank? || seconds <= 0
    mins = seconds.to_i / 60
    secs = seconds.to_i % 60
    mins > 0 ? "#{mins}m #{secs}s" : "#{secs}s"
  end
end
