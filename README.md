# Turn and Push

A service built for Raspberry Pi to handle GitHub web hooks.

To run the server on dev environment cd to `config.ru` directory and execute `rackup`.

Handling URL:

	http://{domain}/handle

Log tail URL (`{lines-number}` is optional parameters to specify amount of lines to get from the end of log file):

	http://{domain}/log/{lines-number}

Manual build execution URL:

	http://{domain}/build/{id}

Example rsync configuration for Rake deploy task:

	ssh_user       = "admin@softtiny.com"
	ssh_port       = "22"
	document_root  = "/var/www/softtiny.com/current/"
	rsync_delete   = true
	rsync_args     = ""
	deploy_default = "rsync"

Setup check list:

- Make sure build server public key is listed in deployment server's `~/.ssh/authorized_keys`.
- Build server public key is added to GitHub deployment keys for all websites.
- Handling URL is added to GitHub webhooks for each website repo.
- `config/sites.yml` is properly configured.
- Webserver could serve static files after rsync (access rights and ownership are ok).
