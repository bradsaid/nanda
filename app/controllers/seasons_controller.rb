# app/controllers/seasons_controller.rb
class SeasonsController < ApplicationController
  def show
    @season   = Season.includes(:series).find(params[:id])
    @episodes = @season.episodes
                       .includes(:location)
                       .order("number_in_season ASC NULLS LAST, id ASC")
  end

  def index
    @seasons = Season.includes(:series).order("series_id ASC, number ASC")

    # Hard-coded map: { "Series Name" => { season_number => { service => url } } }
    @season_services = 
      {
        "Naked and Afraid" => begin
          h = {}
          (1..19).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }

          [4, 5, 11, 12, 14].each { |n| h[n][:disney_plus] = "https://www.disneyplus.com/" }
          [4, 5, 7, 11, 12, 14, 18].each { |n| h[n][:hulu] = "https://www.hulu.com/" }
          [18, 19].each { |n| h[n][:max] = "https://play.hbomax.com/" }
          [17, 18].each { |n| h[n][:discovery_go] = "https://go.discovery.com/" }

          h
        end,

        "Naked and Afraid: Solo" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                discovery_go:   "https://go.discovery.com/" }
        },

        "Naked and Afraid XL" => begin
          h = {}
          (1..10).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }

          h[4][:disney_plus]   = "https://www.disneyplus.com/"
          h[4][:hulu]          = "https://www.hulu.com/"
          [9, 10].each { |n| h[n][:discovery_go] = "https://go.discovery.com/" }

          h
        end,

        "Naked and Afraid: Alone" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                discovery_go:   "https://go.discovery.com/" }
        },

        "Naked And Afraid Savage" => begin
          h = {}
          (1..2).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }

          h[2][:discovery_go] = "https://go.discovery.com/"
          h
        end,

        "Naked and Afraid Castaways" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                disney_plus:    "https://www.disneyplus.com/",
                hulu:           "https://www.hulu.com/",
                discovery_go:   "https://go.discovery.com/" }
        },

        "Naked and Afraid Last One Standing" => begin
          h = {}
          (1..3).each { |n| h[n] = { discovery_plus: "https://www.discoveryplus.com/" } }

          h[3][:hulu]         = "https://www.hulu.com/"
          h[3][:max]          = "https://play.hbomax.com/"
          [2, 3].each { |n| h[n][:discovery_go] = "https://go.discovery.com/" }

          h
        end,

        "Naked and Afraid Apocalypse" => {
          1 => { discovery_plus: "https://www.discoveryplus.com/",
                hulu:           "https://www.hulu.com/",
                max:            "https://play.hbomax.com/" }
        }
      }
  end

end
