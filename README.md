# Turn and Push

A service built for Raspberry Pi to automate Jekyll websites deployment using GitHub web hooks for source update notification, and rsync to deliver static content to the destination web server.

Turn and Push is [Sinatra](http://sinatrarb.com)-based REST service.

## API

Handling URL:

	http://{domain}/handle

Log tail URL (`{lines-number}` is optional parameters to specify amount of lines to get from the end of log file):

	http://{domain}/log/{lines-number}

Manual build execution URL:

	http://{domain}/build/{id}

## Installation

This guide assumes:

- Ruby 2.0 is already present in the system.
- [rbenv](https://github.com/sstephenson/rbenv) is used to control Ruby versions.
- The server is Raspberry Pi running Raspbian Linux.

The only strict prerequisite here is Ruby. TnP could be deployed on ordinary PC hardware running pretty much any major linux distribution.

Get it to the Pi.

	sudo mkdir -p /var/www/turnandpush
	cd /var/www/turnandpush
	sudo chown pi:pi -R .
	git clone git@github.com:dreikanter/turnandpush.git current
	cd current
	bundle install

Update `server_name` value in the `config/nginx.conf` to the actual domain value.

Update `config/sites.yml` with a list of Git repos providing Jekill website sources for building.

Configure passwordless Git access for each website repo via SSH.

Configure passwordless SSH access for each deployment destination.

Add `http://{domain}/handle` to Settings/Service Hooks/WebHook URLs list for each GitHub repo with Jekyll sources, you need to process.

Check deployment configuration inside rakefiles for each Jekyll project. It should work properly on build server environment. Example is below.

	ssh_user       = "admin@softtiny.com"
	ssh_port       = "22"
	document_root  = "/var/www/softtiny.com/current/"
	rsync_delete   = true
	rsync_args     = ""
	deploy_default = "rsync"

Configure nginx.

	sudo apt-get install nginx
	sudo ln -s /var/www/turnandpush/current/config/nginx.conf /etc/nginx/sites-enabled/turnandpush
	sudo service nginx restart

Configure upstart to run unicorn on boot up.

Reboot, check the `ps aux`, and push something to one of the Jekyll repos, to see everything is up and running.
