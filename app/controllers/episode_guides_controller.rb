# Localized (es / pt / fr) episode-guide landing pages. The route supplies :lang as a
# default; anything outside EpisodeGuides::LANGS is a 404. English pages are untouched.
class EpisodeGuidesController < ApplicationController
  def show
    @lang = params[:lang].to_s
    raise ActiveRecord::RecordNotFound, "Unknown guide language: #{@lang}" unless EpisodeGuides.lang?(@lang)

    @guide = EpisodeGuideData.call(today: Date.current)
  end
end
