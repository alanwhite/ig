#!/usr/bin/env ruby
# for testing the IGService class

require_relative "ig_service"

user = ENV["IG_USER"]
pass = ENV["IG_PASS"]
apikey = ENV["IG_API_KEY"]

begin
  ig = IGService.new({ host: 'https://demo-api.ig.com', apikey: apikey })

  res = ig.login(user, pass)
  success = res[:success]
  abort "Login was bad" if !success

  res = ig.getPrice("IX.D.FTSE.DAILY.IP")
  abort "getPrice failed" if !res[:success] 

  puts "FTSE buy #{res[:buy]} sell #{res[:sell]}"

end
