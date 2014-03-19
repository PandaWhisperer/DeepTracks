#!/usr/bin/env ruby

require 'httparty'
require 'ruby-progressbar'

module Spotify
  class API
    include HTTParty
    base_uri "ws.spotify.com"

    def self.search(query)
      get "/search/1/track.json", query: { q: query }
    end
  end
end

# read input from file if filename was given, or STDIN otherwise
input = ARGV.length > 0 ? File.read(ARGV[0]) : STDIN

# parse lines and turn into hashes containing artist, title, and year
tracks = input.lines.map { |l| l =~ %r|(.+) - (.+) \(.+/([0-9]+)|; { artists: $2.split('/'), title: $1, year: $3 } if $& }

# make progress bar
progress = ProgressBar.create(title: "0", total: tracks.size, format: "Matching %c/%C (%t found) |%B|")

# match tracks
matches = []
tracks.compact!.each do |track|
  results = Spotify::API.search "#{track[:artists].join(' ')} #{track[:title]}"

  if results && results['tracks']
    results['tracks'].each do |result|
      if result['album']['released'] == track[:year] &&
         (result['artists'].map { |a| a['name'] } & track[:artists]).any? &&
         result['name'] == track[:title]
        track[:uri] = result['href']
        matches.push track
        progress.title = matches.size
        break
      end
    end
  end

  progress.log "#{track[:artists].join(' / ')} - #{track[:title]} (#{track[:year]}) #{track[:uri] ? '✔︎':''}"
  progress.increment
end

# copy to clipboard
IO.popen('pbcopy', 'w') { |out| out.puts matches.map {|m| m[:uri]} }

# done!
puts "#{matches.size} matches (copied to clipboard)"
