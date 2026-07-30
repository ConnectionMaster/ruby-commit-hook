# git.ruby-lang.org ![test](https://github.com/ruby/git.ruby-lang.org/workflows/test/badge.svg)

## Features

On each commit of Ruby's Git repository, following git hooks are triggered:

### pre-receive

* Verify committer email from `SVN_ACCOUNT_NAME` associated to SSH key used for `git push`
* Reject merge commits (ask @mame about why)

### update

* Sync ruby.git to GitHub

## The directory structure of `git.ruby-lang.org`

* `/data/git/ruby.git`: Bare Git repository of ruby
  * `hooks/pre-receive`: Run `/home/git/git.ruby-lang.org/hooks/pre-receive.sh`
  * `hooks/update`: Run `/home/git/git.ruby-lang.org/hooks/update.sh`
* `/home/git/git.ruby-lang.org`: Cloned Git repository of git.ruby-lang.org

### Notes

* There's a symlink `/var/git` -> `/data/git`.
* User `git`'s `$HOME` is NOT `/home/git` but `/var/git`.

## How to deploy `ruby/git.ruby-lang.org`

### Authentication

* We use only `admin` user for `git.ruby-lang.org`'s SSH access.
  * You should contact @hsbt, @mame or @k0kubun for accessing `git.ruby-lang.org`.

### recipes

```bash
# dry-run
bin/hocho apply -n git.ruby-lang.org

# apply
bin/hocho apply git.ruby-lang.org
```

## Crawler defense

Scrapers forging desktop browser user agents took the site down in June and
July 2026. Fastly is not an option because DNS has to keep pointing at the host
that accepts `git push` over SSH, so the defense runs on the box.

Requests reach cgit through four stages:

```text
client -> apache :443 -> anubis :8923 -> apache :3001 -> cgit.cgi
```

1. `:443` (`sites-available/git.ruby-lang.org.conf`) terminates TLS, serves
   `robots.txt`, 403s the crawlers that name themselves, and 302s the browse
   URLs it can hand to GitHub. Whatever is left it proxies.
2. Git clone requests (`HEAD`, `info/refs`, `objects/`) and `/cgit-css/` skip
   Anubis and go straight to `:3001`. cgit serves the dumb HTTP clone protocol,
   and `git` cannot solve a challenge.
3. Anubis (`anubis@cgit.service`, `/etc/anubis/cgit.botPolicies.yaml`) gives
   everything else a proof-of-work challenge, weighted by how much the client
   looks like a scraper.
4. `:3001` (`sites-available/cgit-backend.conf`) is loopback-only and runs cgit.

Checking on it:

```bash
systemctl status anubis@cgit
journalctl -u anubis@cgit -f
curl -s http://127.0.0.1:9090/metrics | grep anubis_challenges
```

To take Anubis out of the path, point the last three `RewriteRule` lines of the
`:443` vhost back at `http://127.0.0.1:3001/` and reload Apache. Everything
else keeps working.

### TODO for recipes for git.ruby-lang.org

* How to store `ssh_host_key*` and `sshd_config` safely?
* How to write a recipe to mount data volume for bare git repository?
* How to write a recipe for mackerel with the host key of git.ruby-lang.org?

## License

[Ruby License](./license.txt)
