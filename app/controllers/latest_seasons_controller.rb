# /seasons/latest: the most recent season of each active series with its episodes, upcoming
# ones marked, and quick answers computed from air dates. See LatestSeasonGuide. (Its own
# controller: /seasons/:id belongs to SeasonsController, and this route is declared first.)
class LatestSeasonsController < ApplicationController
  def show
    @guide = LatestSeasonGuide.call(today: Date.current)
  end
end
