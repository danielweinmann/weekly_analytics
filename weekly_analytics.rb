require "dotenv/load"
require "oauth2"
require "legato"
require "highline/import"
require "csv"

class User
  extend Legato::Model

  metrics :users
  dimensions :year_week
end

client = OAuth2::Client.new(ENV['LEGATO_OAUTH_CLIENT_ID'], ENV['LEGATO_OAUTH_SECRET_KEY'], {
  :authorize_url => 'https://accounts.google.com/o/oauth2/auth',
  :token_url => 'https://accounts.google.com/o/oauth2/token'
})

authorize_url = client.auth_code.authorize_url({
  :scope => 'https://www.googleapis.com/auth/analytics.readonly',
  :redirect_uri => 'http://localhost',
  :access_type => 'offline'
})

puts
puts "Authorize URL:"
puts
puts authorize_url
puts
auth_code = ask "Please enter the code parameter from Redirect URL: "
access_token = client.auth_code.get_token(auth_code, :redirect_uri => 'http://localhost')
user = Legato::User.new(access_token)

property_ids = ENV['PROPERTY_IDS'].split(',')
profiles = []
user.profiles.each do |profile|
	if property_ids.include?(profile.web_property.id)
		profiles << profile
	end
end

weeks = {}
profiles.each do |profile|
	User.results(profile, start_date: Date.parse(ENV['START_DATE']), sort: ['year_week']).each do |result|
		weeks[result.yearWeek] = [] unless weeks[result.yearWeek]
		weeks[result.yearWeek] << result.users.to_i
	end
end

CSV.open(File.expand_path('../', __FILE__) + "/weekly_analytics.csv", "w") do |csv|
	csv << ["week", "year", "start_date", "end_date", "total_users"]
	weeks.each do |week_year, profiles|
		year = week_year[0..3].to_i
		week = week_year[4..5].to_i
		# No idea why for 2016 Analytics thinks there were 53 weeks and Ruby thinks there were 52
		week -= 1 if year == 2016
		start_date = (Date.commercial(year, week, 1) - 1)
		end_date = (Date.commercial(year, week, 7) - 1)
		total_users = profiles.inject(:+)
		csv << [week, year, start_date, end_date, total_users]
		puts "#{week}/#{year} (from #{start_date} to #{end_date}) => #{total_users}"
	end
end
