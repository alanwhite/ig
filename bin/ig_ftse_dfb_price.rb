#!/usr/bin/env ruby

require 'json'
require 'rest_client'
host = 'https://demo-api.ig.com'
user = ENV["IG_USER"]
pass = ENV["IG_PASS"]
apikey = ENV["IG_API_KEY"]
cst = ENV["IG_CST"]
sectoken = ENV["IG_SECTOKEN"]

begin

	## Get FTSE100 DFB current price
	#
	response = RestClient.get("#{host}/gateway/deal/markets/IX.D.FTSE.DAILY.IP",
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{apikey}",
			:'X-SECURITY-TOKEN' => "#{sectoken}",
			:'CST' => "#{cst}"
		} )

	puts "FTSE market response status: #{response.code}"

	ftse = JSON.parse(response.body)
	bid = ftse["snapshot"]["bid"]
	offer = ftse["snapshot"]["offer"]

	puts "FTSE 100 buy #{offer} sell #{bid}"

	rescue => e
		puts "ERROR: #{e}"

end
