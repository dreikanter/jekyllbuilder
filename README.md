# Turn and Push

This is a RESTful service to automate Jekyll and Octopress websites building and deployment process, using GitHub web hooks for source update notification.

Turn and Push is [Sinatra](http://sinatrarb.com)-based application intended (but not limited) to run on Raspberry Pi and use rsync, AWS CLI or any other tool to deliver static content to the destination web server.

## Installation

This guide assumes:

- Ruby 2.0 and Bundler are already present in the system.
- [rbenv](https://github.com/sstephenson/rbenv) is used to control Ruby versions.
- The server is Raspberry Pi running Raspbian Linux.
- Website sources are hosted on GitHub.
- You are using SSH password-less access for private projects (if there are any).
- You are using rsync for web content deployment, and the access to the destination web servers are preconfigured as well.

The only strict prerequisite here is Ruby. TnP could be deployed on ordinary PC hardware running pretty much any major Linux distribution.

### Getting everything up and running

Get it to the Pi.

	sudo mkdir -p /var/www/turnandpush
	cd /var/www/turnandpush
	sudo chown pi:pi -R .
	git clone git@github.com:dreikanter/turnandpush.git current
	cd current
	bundle install

Update `server_name` value in the `config/nginx.conf` to the actual domain value.

Copy `config/example-sources.yml` to `config/sources.yml` and update it with the actual sources configuration.

Configure password-less Git access for each website repo via SSH.

Configure password-less SSH access for each deployment destination.

Add `http://{your-domain}/handle` to Settings/Service Hooks/WebHook URLs list for each GitHub repo with Jekyll sources, you need to process.

Check deployment configuration inside rakefiles for each Jekyll project. It should work properly on build server environment. Example is below.

	ssh_user       = "admin@example.com"
	ssh_port       = "22"
	document_root  = "/var/www/example.com/current/"
	rsync_delete   = true
	rsync_args     = ""
	deploy_default = "rsync"

Configure nginx.

	sudo apt-get install nginx
	sudo ln -s /var/www/turnandpush/current/config/nginx.conf /etc/nginx/sites-enabled/turnandpush
	sudo service nginx restart

For Raspberry Pi: install upstart if it was not installed before.

	sudo apt-get install upstart --force-yes

Configure upstart to run unicorn on boot up.

	sudo ln -s /var/www/turnandpush/current/config/upstart.conf /etc/init/turnandpush.conf

Reboot, check if there are nginx and unicorn in the process list (`ps aux`), and [test GitHub web hooks](https://help.github.com/articles/testing-webhooks) to see everything is working.

### Troubleshooting

- "Liquid Exception: Pygments can't parse unknown language: ruby."

  Jekyll/Octopress uses pygments.rb gem, which is Ruby wrapper for Python Pygments library. Make shure the default Python version on your system is 2.7.*. Pygments is not working with Python 3 for some reason.
  
- "YAML Exception reading invalid byte sequence in US-ASCII"

  This error could be caused by BOM prefix in post/page files, or bad system locale. To fix second problem TNP overrides `LC_CTYPE` and `LANG` environment variables with the value of `en_US.UTF-8`. To fix the first problem (if encountered) just save text files without BOM with your text editor.
  
- At the moment of writing Octopress may crash when using Ruby 2.0. Make shure 1.9.3 is installed in your system, and use your Ruby version manager (rbenv or RVM) to define specific version for the build.


## API

Handling URL:

	http://{domain}/handle

Manual build request:

	GET http://{domain}/build/{owner}/{repository}

`{owner}/{repository}` should be the same as in GitHub URL. For example to build `http://github.com/dreikanter/jekyll-test.git`, you should seng GET request to `http://turnandpush.domain.com/dreikanter/jekyll-test`.

Log tail request:

	GET http://{domain}/log/{lines-number}

`{lines-number}` is an optional parameter to specify amount of lines to get from the end of log file. By default `/log` will return 10 lines.

## Why Turn and Push?

You don't want to know ಠ_ಠ

![Turn and Push GIF](https://raw.github.com/dreikanter/turnandpush/cd5791005d3d1c92d452d3549f2d4143ae6786a2/public/turn-and-push.gif)
