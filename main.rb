require "mini_magick"
require 'nokogiri'
require 'open-uri'
require 'webrick/httputils'
require 'json'
require 'fuzzystringmatch'
require 'date'
ROOT = "https://www.last.fm/music/"
DIR = ARGV[0]
JSON_STATS = JSON.parse File.read("#{DIR}stats.json"), { :symbolize_names => true}
MONTHS = %w[January February March April May June July August September October November December]

def get_image(album)
  artist = album[0].gsub(" ", "+")
  album_title = album[1..album.length - 1].join(" - ").gsub(" ", "+")
  begin
    query = WEBrick::HTTPUtils.escape "#{ROOT}#{artist}/#{album_title}"
    puts query
    page = Nokogiri.HTML(URI.open(query), nil, "UTF-8")
    page.at_css("a.cover-art img")["src"]
  rescue NoMethodError, OpenURI::HTTPError
    puts "Error: Could not retrieve URL, using most probable alternative"
    album_found = find_album artist, album_title
    query = WEBrick::HTTPUtils.escape "https://www.last.fm#{album_found["href"]}"
    puts query
    page = Nokogiri.HTML(URI.open(query), nil, "UTF-8")
    page.at_css("a.cover-art img")["src"]
  end
end

def find_album(artist, album)
  query = WEBrick::HTTPUtils.escape "#{ROOT}#{artist}/+albums"
  page = Nokogiri.HTML(URI.open(query), nil, "UTF-8")
  albums = page.css("a.link-block-target[href^=\"/music/#{artist}\"]")
  matches = {}
  jarow = FuzzyStringMatch::JaroWinkler.create :pure
  albums.each do |a|
    matches[a.text] = jarow.getDistance album, a.text
  end
  matches = matches.sort_by{|k,v| -v}.to_h
  index = albums.find_index {|a| a.text == matches.keys[0]}
  albums[index]
end

def make_row_2(images)
  filename = "/tmp/#{SecureRandom.hex(8)}.png"
  resized_images = [MiniMagick::Image.open(images[0]).resize("800x1000"), MiniMagick::Image.open(images[1]).resize("800x1000")]
  system "convert #{resized_images[0].path} #{resized_images[1].path} +append #{filename}"
  filename
end

def make_row_3(images)
  filename = "/tmp/#{SecureRandom.hex(8)}.png"
  resized_images = [MiniMagick::Image.open(images[0]).resize("500x600"), MiniMagick::Image.open(images[1]).resize("500x600"), MiniMagick::Image.open(images[2]).resize("500x600")]
  system "convert #{resized_images[0].path} #{resized_images[1].path} #{resized_images[2].path} +append #{filename}"
  filename
end

def make_row_4(images)
  filename = "/tmp/#{SecureRandom.hex(8)}.png"
  resized_images = [MiniMagick::Image.open(images[0]).resize("400x500"), MiniMagick::Image.open(images[1]).resize("400x500"),
                    MiniMagick::Image.open(images[2]).resize("400x500"), MiniMagick::Image.open(images[3]).resize("400x500")
  ]
  system "convert #{resized_images[0].path} #{resized_images[1].path} #{resized_images[2].path} #{resized_images[3].path} +append #{filename}"
  filename
end

today = Date.today
tomorrow = Date.today + 1
filename_month = "#{DIR}Mosaic#{MONTHS[today.month-1]}#{today.year}.png"
filename_year = "#{DIR}Mosaic#{today.year}.png"

#if today.month != tomorrow.month
monthly_list = JSON_STATS[:this_month][:albums_time].sort_by{|k, v| -v }.to_h
images_month = []
monthly_list.keys[0..9].each do |a|
  images_month += [get_image(a.to_s.split(" - "))]
end
row1 = make_row_3 images_month.reverse[0..2]
row2 = make_row_3 images_month.reverse[3..5]
row3 = make_row_3 images_month.reverse[6..8]
month_row4 = images_month.reverse[9]
image_row4 = MiniMagick::Image.open(month_row4).resize("1500x1800")
system "convert #{row1} #{row2} #{row3} #{image_row4.path} -append #{filename_month}"
#end

#if today.year != tomorrow.year
yearly_list = JSON_STATS[:this_year][:albums_time].sort_by{|k,v| -v}.to_h
images_year = []
yearly_list.keys[0..19].each do |a|
  images_year += [get_image(a.to_s.split(" - "))]
end
row1 = make_row_4 images_year.reverse[0..3]
row2 = make_row_4 images_year.reverse[4..7]
row3 = make_row_4 images_year.reverse[8..11]
row4 = make_row_4 images_year.reverse[12..15]
row5 = make_row_2 images_year.reverse[16..17]
row6 = make_row_2 images_year.reverse[18..19]
system "convert #{row1} #{row2} #{row3} #{row4} #{row5} #{row6} -append #{filename_year}"
#end
