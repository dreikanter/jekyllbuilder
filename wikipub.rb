require 'addressable/uri'
require 'fileutils'
require 'gollum-lib'

# GitHub wiki URL
REPO_URL = 'git@github.com:username/project.wiki.git'

# Local directory path for temp files
TEMP_PATH = File.join Dir.pwd, 'tmp'

# Destination path for rsync
RSYNC_DEST = 'admin@example.com:/var/www/example.com/current/wiki'

# Presence of this marker tells that the wiki page should be exported
EXPORT_MARKER = '<export>'

TEMPLATE_FILE = File.expand_path '../config/template.html', __FILE__

def sh(command)
  puts "Executing shell command: #{command}"
  system command
end

uri = Addressable::URI.parse(REPO_URL)
owner, repo = uri.path.gsub(/(^\/+)/, '').split('/', 2)
tmp_dir = File.join TEMP_PATH, "#{owner}--#{repo}"

# Fetch wiki data from GitHub

if File.directory? tmp_dir
  puts 'Updating local repository'
  cmd = [
    "cd #{tmp_dir}",
    "git fetch --all",
    "git reset --hard origin/master"
    ].join(' && ')
  unless sh(cmd)
    puts 'Error merging remote changes'
    puts 'Purging local copy'
    FileUtils.rm_rf tmp_dir
  end
end

unless File.directory? tmp_dir
  puts "Cloning #{REPO_URL} to #{tmp_dir}"
  cmd = "git clone #{REPO_URL} #{tmp_dir}"
  puts 'Error getting site source' unless sh(cmd)
end

# Process markdown

output_dir = "#{tmp_dir}-output"
FileUtils.rm_rf output_dir if File.directory? output_dir
FileUtils.mkdir_p output_dir
wiki = Gollum::Wiki.new(tmp_dir, :base_path => '/wiki')
tpl = File.open(TEMPLATE_FILE, 'r:UTF-8') { |f| f.read }

wiki.pages.each do |page|
  next unless page.raw_data.include? EXPORT_MARKER
  output_file = File.join output_dir, File.basename(page.filename, '.*')
  File.open(output_file, 'w:UTF-8') do |f|
    f.write(tpl % { :title => page.title, :content => page.formatted_data })
  end
end

# Push the tempo!

output_dir << '/' unless output_dir.end_with?('/')
sh "rsync -avz --delete '#{output_dir}' '#{RSYNC_DEST}'"
