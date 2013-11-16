require 'bundler/setup'
require 'sinatra'
require 'json'
require 'pp'

class TurnAndPushApp < Sinatra::Base
  configure :development do
    set :logging, Logger::DEBUG
  end

  configure :production do
    set :logging, Logger::INFO
  end


  before do
    logger = Logger.new(File.expand_path('../log/app.log', __FILE__), 'weekly')
    logger.formatter = proc do |severity, datetime, progname, msg|
       "#{datetime.strftime('%F %T')} #{severity}: #{msg}\n"
    end
    env['rack.logger'] = logger
  end

  post '/handle' do
    logger.debug("Receiving Webhook #{params[:webhookId]}")
    logger.debug(JSON.parse(params[:result]))
    # TODO: clone last revision to templ location; build; sync; delete
  end

  get '/build/:id' do
    # Manual execute build for specific website
    # TODO: clone last revision to templ location; build; sync; delete
  end

  get '/status' do
    logger.info('Hello!')
  end

  not_found do
    '404'
  end
end
