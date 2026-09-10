execute 'systemctl daemon-reload' do
  action :nothing
end

directory '/etc/systemd/system/apache2.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/apache2.service.d/override.conf' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload]'
  notifies :restart, 'service[apache2]'
end

service 'apache2' do
  action :nothing
end

remote_file '/var/www/git.ruby-lang.org/robots.txt' do
  mode  '644'
  owner 'root'
end

remote_file '/etc/apache2/conf-available/cgit.conf' do
  mode  '644'
  owner 'root'
  notifies :reload, 'service[apache2]'
end

link '/etc/apache2/conf-enabled/cgit.conf' do
  to '../conf-available/cgit.conf'
end

%w[git svn].each do |subdomain|
  remote_file "/etc/apache2/sites-available/#{subdomain}.ruby-lang.org.conf" do
    mode  '644'
    owner 'root'
    notifies :reload, 'service[apache2]'
  end

  link "/etc/apache2/sites-enabled/#{subdomain}.ruby-lang.org.conf" do
    to "../sites-available/#{subdomain}.ruby-lang.org.conf"
  end
end

# The cgit backend introduces a new Listen directive, which a reload does not
# pick up.
remote_file '/etc/apache2/sites-available/cgit-backend.conf' do
  mode  '644'
  owner 'root'
  notifies :restart, 'service[apache2]'
end

link '/etc/apache2/sites-enabled/cgit-backend.conf' do
  to '../sites-available/cgit-backend.conf'
  notifies :restart, 'service[apache2]'
end

# proxy, proxy_http and headers carry the hop through Anubis. remoteip lets the
# backend vhost log the real client instead of 127.0.0.1.
{
  'ssl'        => %w[conf load],
  'cgid'       => %w[conf load],
  'proxy'      => %w[conf load],
  'proxy_http' => %w[load],
  'rewrite'    => %w[load],
  'headers'    => %w[load],
  'remoteip'   => %w[load],
}.each do |mod, exts|
  exts.each do |ext|
    link "/etc/apache2/mods-enabled/#{mod}.#{ext}" do
      to "../mods-available/#{mod}.#{ext}"
      notifies :restart, 'service[apache2]'
    end
  end
end

# root's crontab carried "20 * * * * systemctl restart apache2" from before
# Anubis, outside this repository. It fixed nothing: children settle at 25 MB
# and never leak. It caused harm instead. 57 of the 91 AH00484 (MaxRequestWorkers
# exhausted) events in the last two weeks landed within eight minutes of it,
# because the 63,000 requests an hour arriving at the front door all reconnect
# at once against StartServers 2.
file '/var/spool/cron/crontabs/root' do
  action :delete
end
