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
  def login(username:, password:)

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
  def getPrice(epic:)
    
    response = RestClient.get("#{@host}/gateway/deal/markets/#{epic}", @headers ) 

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
  # place a sell order
  #
  def oldPlaceSellOrder(epic:,size:,price:,params: {} )

    limit_sell_map = {
      :"epic" => epic,
      :"expiry" => "DFB",
      :"direction" => "SELL",
      :"size" => size,
      :"level" => price,
      :"type" => "LIMIT",
      :"currencyCode" => "GBP",
      :"timeInForce" => "GOOD_TILL_CANCELLED",
      :"guaranteedStop" => "false"
    }.merge(params)

    response = RestClient.post("#{@host}/gateway/deal/workingorders/otc",
      limit_sell_map.to_json, @headers ) 

    if response.code == 200
      orderresp = JSON.parse(response.body)
      dealref = orderresp["dealReference"]
      { :success => true, :dealref => dealref }
    else
      { :success => false }
    end

    rescue => e
      puts "placeSellOrder ERROR: #{e}"
      { :success => false }

  end

  ###
  # Place a sell order
  #
  def placeSellOrder(epic:,size:,price:,params: {} )

    sell_order_params = {
      :"epic" => epic,
      :"size" => size,
      :"level" => price,
      :"type" => "LIMIT"
    }

    placeOrder(params: sell_order_params.merge(params))

  end

  ###
  # Place a buy order
  #
  def placeBuyOrder(epic:,size:,price:,params: {} )

    buy_order_params = {
      :"epic" => epic,
      :"size" => size,
      :"level" => price,
      :"type" => "STOP"
    }

    placeOrder(params: buy_order_params.merge(params))

  end

  ###
  # place an order
  #
  def placeOrder(params: {} )

    order_details_map = {
      :"expiry" => "DFB",
      :"direction" => "SELL",
      :"type" => "LIMIT",
      :"currencyCode" => "GBP",
      :"timeInForce" => "GOOD_TILL_CANCELLED",
      :"guaranteedStop" => "false"
    }.merge(params)
    
    response = RestClient.post("#{@host}/gateway/deal/workingorders/otc",
      order_details_map.to_json, @headers ) 

    if response.code == 200
      orderresp = JSON.parse(response.body)
      dealref = orderresp["dealReference"]
      { :success => true, :dealref => dealref }
    else
      { :success => false }
    end

    rescue => e
      puts "placeOrder ERROR: #{e}"
      { :success => false }
  end

  ###
  # get status of an order
  #
  def checkOrder(dealref)

    response = RestClient.get("#{@host}/gateway/deal/confirms/#{dealref}", @headers )
    if response.code == 200
      confbody = JSON.parse(response.body)
      { :success => true, :dealstatus => confbody['dealStatus'], 
        :reason => confbody['reason'], :status => confbody['status'] }
    else
      { :success => false }
    end

    rescue => e
      puts "checkOrder ERROR: #{e}"
      { :success => false }

  end  

end
