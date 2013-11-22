require 'json'
require 'httparty'
require 'pp'

# params = { :repository => { :name => 'softtiny.com' } }
# puts params.to_json

re = HTTParty.get('http://192.168.1.111:8000/log/100')
pp re.response.code
pp re
