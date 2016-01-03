# app/services/ig_service.rb

require 'json'
require 'rest_client'

class IGService
  def initialize(params)
    @host = params[:host]
    @apikey = params[:apikey]
  end

  ###
  # login to IG
  #
  def login(username, password)

	request_body_map = {
		:'identifier' => "#{username}",
		:'password' => "#{password}"
	}

	response = RestClient.post("#{@host}/gateway/deal/session",
		request_body_map.to_json,
		{
			:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{@apikey}"
		} )

	if response.code == 200
      @cst = response.headers[:'cst']
      @sectoken = response.headers[:'x_security_token']
      @headers = {
	  		:content_type => 'application/json; charset=UTF-8',
			:accept => 'application/json; charset=UTF-8',
			:'X-IG-API-KEY' => "#{@apikey}",
            :'X-SECURITY-TOKEN' => "#{@sectoken}",
            :'CST' => "#{@cst}"
		}

      { :success => true }
    else
      { :success => false }
    end

	rescue => e
		puts "login ERROR: #{e}"
        { :success => false }

  end

  ###
  # get buy/sell price
  #
  def getPrice(instrument)
    
    response = RestClient.get("#{@host}/gateway/deal/markets/#{instrument}", @headers ) 

    if response.code == 200
      ftse = JSON.parse(response.body)
      bid = ftse["snapshot"]["bid"]
      offer = ftse["snapshot"]["offer"]
      { :success => true, :buy => bid, :sell => offer }
    else
      { :success => false }
    end

    rescue => e
      puts "getPrice ERROR: #{e}"
      { :success => false }
  end

  ###
  # place a sell order for a dfb 
  #
  def sellDFB(instrument,size,price,params)

    limit_sell_map = {
      :"epic" => instrument,
      :"expiry" => "DFB",
      :"direction" => "SELL",
      :"size" => size,
      :"level" => price,
      :"type" => "LIMIT",
      :"currencyCode" => "GBP",
      :"timeInForce" => "GOOD_TILL_CANCELLED",
      :"guaranteedStop" => "false"
    }.merge(params)

    response = RestClient.post("#{host}/gateway/deal/workingorders/otc",
      limit_sell_map.to_json, @headers ) 

    puts "FTSE sell limit order response status: #{response.code}"
    # puts response.body
    orderresp = JSON.parse(response.body)
    dealref = orderresp["dealReference"]
  end

  ### 
  # place a buy order for a dfb
  #
  def buyDFB(instrument,price,size,params)
  end


end
