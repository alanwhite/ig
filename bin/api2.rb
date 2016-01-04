#!/usr/bin/env ruby
# for testing the IGService class

require_relative "ig_service"

user = ENV["IG_USER"]
pass = ENV["IG_PASS"]
apikey = ENV["IG_API_KEY"]

begin
  puts "IGService Demo"
  ig = IGService.new({ host: 'https://demo-api.ig.com', apikey: apikey })

  ###
  # Log in and get current FTSE prices
  #
  res = ig.login(username: user, password: pass)
  success = res[:success]
  abort "Login was bad" if !success

  res = ig.getPrice(epic: "IX.D.FTSE.DAILY.IP")
  abort "getPrice failed" if !res[:success] 

  buyPrice = res[:buy]
  sellPrice = res[:sell]
  puts "FTSE buy #{buyPrice} sell #{sellPrice}"

  ###
  # Place a sell order 100 points above current sell price, stop and limit 100 pts away
  #
  res = ig.placeSellOrder(epic: "IX.D.FTSE.DAILY.IP",size: 2, price:sellPrice+100, 
    params: {
      :"stopDistance" => 100,
      :"limitDistance" => 100
    }
  )
  abort "placeSellOrder failed" if !res[:success]

  sellDealRef = res[:dealref]
  puts "Sell order placed with Deal Reference #{sellDealRef}"
  
  res = ig.checkOrder(sellDealRef)
  abort "checkOrder failed" if !res[:success]

  puts "Confirm sell order dealStatus #{res[:dealstatus]} reason #{res[:reason]} status #{res[:status]}"

  ###
  # Place a buy order 100 points below current FTSE price, no stop or limit
  #
  res = ig.placeBuyOrder(epic: "IX.D.FTSE.DAILY.IP",size: 2,price: buyPrice-100)
  abort "placeBuyOrder failed" if !res[:success]

  buyDealRef = res[:dealref]
  puts "Buy order placed with Deal Reference #{buyDealRef}"
  
  res = ig.checkOrder(buyDealRef)
  abort "checkOrder failed" if !res[:success]

  puts "Confirm buy order dealStatus #{res[:dealstatus]} reason #{res[:reason]} status #{res[:status]}"





  puts "IGService Demo Complete"

end
