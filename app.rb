require 'addressable/uri'
require 'bundler/setup'
require 'fileutils'
require 'json'
require 'logger'
require 'sinatra'
require 'yaml'

# Path to the git sources definition file
SOURCE_FILE = File.join settings.root, 'config/sources.yml'

# Path to variables difinition to export for Jekyll
VAR_FILE = File.join settings.root, 'config/variables.yml'

# Path to the GitHub wiki sources definition file
WIKIS_FILE = File.join settings.root, 'config/wikis.yml'

# Temporary dir for website building
TMP_DIR = File.join settings.root, 'tmp'

# Application log file
LOG_FILE = File.join settings.root, "log/#{settings.environment}.log"

# Default tail length
TAIL_LENGTH = 30

# Presence of this marker tells that the wiki page should be exported
EXPORT_MARKER = '<export>'

TEMPLATE_FILE = File.join settings.root, 'config/template.html'

class TurnAndPushApp < Sinatra::Base
  configure do
    enable :logging
  end

  configure :development, :test do
    set :logging, Logger::DEBUG
  end

  before do
    content_type 'text/plain', :charset => 'utf-8'
  end

  post '/handle' do
    data = JSON.parse params[:payload]
    owner = data['repository']['owner']['name']
    repo = data['repository']['name']
    logger.info "Handling webhook: #{owner}/#{repo}"
    build(owner, repo)
  end

  get '/build/:name' do
    name = params[:name]
    error 401, 'Source name undefined' unless name
    build(name)
  end

  get '/publish/:name' do
    name = params[:name]
    error 401, 'Source name undefined' unless name
    publish(name)
  end

  get '/log' do
    tail
  end

  get '/log/:n' do
    error 401, 'Bad number' unless params[:n].to_s =~ /^\d{,4}$/
    tail(params[:n])
  end

  not_found do
    error 405, 'Go away!'
  end

  def sources()
    result = {}
    begin
      YAML.load_file(SOURCE_FILE).each do |name, source|
        path = Addressable::URI.parse(source['url']).path
        owner, repo = path.gsub(/(^\/+)|(\.git$)/, '').split('/', 2)
        result[name] = {
          :url => source['url'],
          :owner => owner,
          :repo => repo,
          :build => source['build'],
          :deploy => source['deploy'],
        }
      end
    rescue => e
      logger.error "Error loading sources from #{SOURCE_FILE}"
      error 500, 'Configuration error'
    end
    return result
  end

  def wikis()
    begin
      return YAML.load_file(WIKIS_FILE)
    rescue => e
      logger "Error loading sources from #{WIKIS_FILE}"
      error 500, 'Configuration error'
    end
  end

  def build(source_name)
    start_time = start = Time.now
    source = sources[source_name]
    error 401, 'Undefined source' unless source
    tmp_dir = File.join TMP_DIR, "#{source_name}"

    if File.directory? tmp_dir
      logger.info 'Updating local repository'
      cmd = [
        "cd #{tmp_dir}",
        "git fetch --all",
        "git reset --hard origin/master"
        ].join(' && ')
      unless sh(cmd)
        logger.error 'Error merging remote changes'
        logger.info 'Purging local copy'
        FileUtils.rm_rf tmp_dir
      end
    end

    unless File.directory? tmp_dir
      logger.info "Cloning #{source[:url]} to #{tmp_dir}"
      cmd = "git clone #{source[:url]} #{tmp_dir}"
      error 500, 'Error getting site source' unless sh(cmd)
    end

    logger.info 'Building website'
    cmd = [
      "cd #{tmp_dir}",
      "export LC_CTYPE=en_US.UTF-8",
      "export LANG=en_US.UTF-8",
      "export BUNDLE_GEMFILE=#{tmp_dir}/Gemfile",
      "export JEKYLL_VARIABLES=#{VAR_FILE}",
      "#{source[:build]}"
    ].join(' && ')

    error 500, 'Error building website' unless sh(cmd)

    logger.info 'Deploying website'
    cmd = "cd #{tmp_dir} && #{source[:deploy]}"
    error 500, 'Error deploying website' unless sh(cmd)

    seconds = (Time.now - start_time).round(2)
    logger.info "Finished in #{seconds} seconds."

    halt 200, 'Ok'
  end

  def publish(source_name)
    start_time = start = Time.now
    source = wikis[source_name]
    logger.info source
    error 401, 'Undefined source' unless source
    tmp_dir = File.join TMP_DIR, "#{source_name}.wiki"

    logger.info 'Fetching wiki data'
    if File.directory? tmp_dir
      logger.info 'Updating local repository'
      cmd = [
        "cd #{tmp_dir}",
        "git fetch --all",
        "git reset --hard origin/master"
        ].join(' && ')
      unless sh(cmd)
        logger.error 'Error merging remote changes'
        logger.info 'Purging local copy'
        FileUtils.rm_rf tmp_dir
      end
    end

    unless File.directory? tmp_dir
      logger.info "Cloning #{source['url']} to #{tmp_dir}"
      cmd = "git clone #{source['url']} #{tmp_dir}"
      logger.info 'Error getting site source' unless sh(cmd)
    end

    logger.info 'Building wiki pages'
    output_dir = "#{tmp_dir}.wiki.output"
    FileUtils.rm_rf output_dir if File.directory? output_dir
    FileUtils.mkdir_p output_dir
    wiki = Gollum::Wiki.new(tmp_dir, :base_path => source['base_path'])
    tpl = File.open(TEMPLATE_FILE, 'r:UTF-8') { |f| f.read }

    wiki.pages.each do |page|
      next unless page.raw_data.include? EXPORT_MARKER
      output_file = File.join output_dir, File.basename(page.filename, '.*')
      File.open(output_file, 'w:UTF-8') do |f|
        f.write(tpl % { :title => page.title, :content => page.formatted_data })
      end
    end

    logger.info 'Pushing the tempo!'
    output_dir << '/' unless output_dir.end_with?('/')
    sh source['deploy'] % output_dir

    logger.info 'Clean up'
    logger.info 'Cleaning up temporary files'
    FileUtils.rm_rf tmp_dir if File.directory? tmp_dir
    FileUtils.rm_rf output_dir if File.directory? output_dir

    seconds = (Time.now - start_time).round(2)
    logger.info "Finished in #{seconds} seconds."

    halt 200, 'Ok'
  end

  def tail(num=TAIL_LENGTH)
    error 500, 'Log file not exists' unless File.exists? LOG_FILE
    logger.info "Reading #{num} lines from log tail"
    sh("tail -n #{num} #{LOG_FILE}")
  end

  def error(code, message)
    logger.fatal(message)
    halt code, message
  end

  def sh(command)
    logger.info "Executing shell command: #{command}"
    system command
  end
end
