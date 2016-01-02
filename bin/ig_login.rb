#!/usr/bin/env ruby

require 'json'
require 'rest_client'
host = 'https://demo-api.ig.com'
user = ENV["IG_USER"]
pass = ENV["IG_PASS"]
apikey = ENV["IG_API_KEY"]

begin

	## Login
	#
	request_body_map = {
		:'identifier' => "#{user}",
		:'password' => "#{pass}"
	}

	response = RestClient.post("#{host}/gateway/deal/session",
		request_body_map.to_json,
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{apikey}"
		} )

	puts "Login response status: #{response.code}"

    puts "export IG_CST=#{response.headers[:'cst']}"
    puts "export IG_SECTOKEN=#{response.headers[:'x_security_token']}"

	rescue => e
		puts "ERROR: #{e}"

end
