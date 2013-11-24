require 'bundler'

Bundler.require
require File.expand_path '../app.rb', __FILE__

# logger = Logger.new("log/#{ENV['RACK_ENV']}.log")
# use Rack::CommonLogger, logger

run TurnAndPushApp
