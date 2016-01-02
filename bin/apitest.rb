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

	cst = response.headers[:'cst']
	sectoken = response.headers[:'x_security_token']

	# puts response.body

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

	## place sell order 100 points above with contingent stop and limit 100 points either side
	#
	sellprice = offer+100
	limit_sell_map = {
		:"epic" => "IX.D.FTSE.DAILY.IP",
		:"expiry" => "DFB",
		:"direction" => "SELL",
		:"size" => "2",
		:"level" => "#{sellprice}",
		:"type" => "LIMIT",
		:"currencyCode" => "GBP",
		:"timeInForce" => "GOOD_TILL_CANCELLED",
		:"guaranteedStop" => "false",
		:"stopDistance" => "100",
		:"limitDistance" => "100"
	}

	response = RestClient.post("#{host}/gateway/deal/workingorders/otc",
		limit_sell_map.to_json,
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{apikey}",
			:'X-SECURITY-TOKEN' => "#{sectoken}",
			:'CST' => "#{cst}"
		} )

	puts "FTSE sell limit order response status: #{response.code}"
	# puts response.body
	orderresp = JSON.parse(response.body)
	dealref = orderresp["dealReference"]
	puts "Placed order with ref #{dealref}"

	response = RestClient.get("#{host}/gateway/deal/confirms/#{dealref}",
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{apikey}",
			:'X-SECURITY-TOKEN' => "#{sectoken}",
			:'CST' => "#{cst}"
		} )

	puts "Confirm orders status #{response.code}"
	oconfbody = JSON.parse(response.body)
	puts "Confirm dealStatus #{oconfbody['dealStatus']} reason #{oconfbody['reason']} status #{oconfbody['status']}"

	## list working orders
	#
	response = RestClient.get("#{host}/gateway/deal/workingorders",
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{apikey}",
			:'X-SECURITY-TOKEN' => "#{sectoken}",
			:'CST' => "#{cst}"
		} )


	puts "List active orders response status: #{response.code}"
	orders = JSON.parse(response.body)

	orders['workingOrders'].each do |child|
		dealid = child['workingOrderData']['dealId']
		puts "Deleting dealId #{dealid}"

		response = RestClient.post("#{host}/gateway/deal/workingorders/otc/#{dealid}", JSON.generate({}),
			{
				:content_type => 'application/json; charset=UTF-8',
				:accept => 'application/json; charset=UTF-8',
				:'X-IG-API-KEY' => "#{apikey}",
				:'X-SECURITY-TOKEN' => "#{sectoken}",
				:'CST' => "#{cst}",
				"_method" => "DELETE"
			} )

		puts "Delete status #{response.code}"
		delbody = JSON.parse(response.body)
		dealreference = delbody["dealReference"]
		puts "Check status of delete #{dealreference}"

		response = RestClient.get("#{host}/gateway/deal/confirms/#{dealreference}",
			{
				:content_type => 'application/json; charset=UTF-8',
				:accept => 'application/json; charset=UTF-8',
				:'X-IG-API-KEY' => "#{apikey}",
				:'X-SECURITY-TOKEN' => "#{sectoken}",
				:'CST' => "#{cst}"
			} )

		puts "Confirms status #{response.code}"
		confbody = JSON.parse(response.body)
		puts "Confirm dealStatus #{confbody['dealStatus']} reason #{confbody['reason']} status #{confbody['status']}"
	end

	rescue => e
		puts "ERROR: #{e}"

end
