require 'bundler/setup'
require 'logger'
require 'sinatra'

class TurnAndPushApp < Sinatra::Base
  configure do
    set :clean_trace, true
    enable :logging
    # logger = Logger.new('log/common.log', 'weekly')
    # logger.datetime_format = "%Y/%m/%d %H:%M:%S "
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end

  configure :development do
    set :logging, Logger::DEBUG
  end

  configure :production do
    set :logging, Logger::INFO
  end

  post '/handle' do
    # Handle GitHub web hook
  end

  get '/build/:id' do
    # Execute build for specific website
  end

  get '/status' do
    # Show status
  end
end
