# Anubis (https://github.com/TecharoHQ/anubis) sits between the Apache TLS
# vhost and the cgit backend and makes clients that look like scrapers solve a
# proof-of-work challenge before cgit renders anything for them.
#
# Debian has no Anubis package, so the upstream .deb is installed by hand and
# pinned by version and checksum.
ANUBIS_VERSION = '1.26.2'
ANUBIS_DEB_SHA256 = 'd346526cbcd66e6bc438a45fc8d6ad1317c9bac8f6472bdec57f87ae17b91728'
ANUBIS_DEB_URL = "https://github.com/TecharoHQ/anubis/releases/download/v#{ANUBIS_VERSION}/anubis_#{ANUBIS_VERSION}_amd64.deb"

execute 'systemctl daemon-reload (anubis)' do
  command 'systemctl daemon-reload'
  action :nothing
end

execute "install anubis #{ANUBIS_VERSION}" do
  command <<~COMMAND
    set -eu
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT
    deb="$workdir/anubis_#{ANUBIS_VERSION}_amd64.deb"
    wget -q -O "$deb" '#{ANUBIS_DEB_URL}'
    echo '#{ANUBIS_DEB_SHA256}  '"$deb" | sha256sum -c -
    apt-get install -y "$deb"
  COMMAND
  not_if "dpkg-query -W -f='${Version}' anubis 2>/dev/null | grep -qx '#{ANUBIS_VERSION}'"
  notifies :restart, 'service[anubis@cgit]'
end

directory '/etc/anubis' do
  mode  '755'
  owner 'root'
end

# The ed25519 key signs the challenge cookies. Without a stable key every
# restart invalidates the cookies of everyone who has already passed. It is a
# secret, so it is generated on the host instead of living in this repository,
# and it goes in its own EnvironmentFile that systemd reads as root.
execute 'generate anubis signing key' do
  command <<~COMMAND
    set -eu
    umask 077
    printf 'ED25519_PRIVATE_KEY_HEX=%s\\n' "$(openssl rand -hex 32)" > /etc/anubis/cgit.secret.env
  COMMAND
  not_if 'test -s /etc/anubis/cgit.secret.env'
  notifies :restart, 'service[anubis@cgit]'
end

directory '/etc/systemd/system/anubis@cgit.service.d' do
  mode  '755'
  owner 'root'
end

remote_file '/etc/systemd/system/anubis@cgit.service.d/override.conf' do
  mode  '644'
  owner 'root'
  notifies :run, 'execute[systemctl daemon-reload (anubis)]'
  notifies :restart, 'service[anubis@cgit]'
end

%w[cgit.env cgit.botPolicies.yaml].each do |name|
  remote_file "/etc/anubis/#{name}" do
    mode  '644'
    owner 'root'
    notifies :restart, 'service[anubis@cgit]'
  end
end

service 'anubis@cgit' do
  action [:enable, :start]
end
