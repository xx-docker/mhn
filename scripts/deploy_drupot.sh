set -e
set -x

if [ $# -ne 2 ]
    then
        echo "Wrong number of arguments supplied."
        echo "Usage: $0 <server_url> <deploy_key>."
        exit 1
fi

server_url=$1
deploy_key=$2

apt-get update
apt-get -y install git supervisor

####################################################################
# Install a decent version of golang
if [ "$(uname -m)" == "x86_64" ] ;
then
    GO_PACKAGE="go1.12.6.linux-amd64.tar.gz"
else
    GO_PACKAGE="go1.12.6.linux-386.tar.gz"
fi

cd /usr/local/
wget https://storage.googleapis.com/golang/${GO_PACKAGE}
tar zxf ${GO_PACKAGE} && rm ${GO_PACKAGE}

cd /usr/bin/
for X in /usr/local/go/bin/*; 
do 
    echo $X; 
    ln -s $X; 
done
####################################################################

export GO111MODULE=on

# Get the drupot source
cd /opt
git clone https://github.com/d1str0/drupot.git
cd drupot
git checkout v0.2.3

go build

# Register the sensor with the MHN server.
wget $server_url/static/registration.txt -O registration.sh
chmod 755 registration.sh
# Note: this will export the HPF_* variables
. ./registration.sh $server_url $deploy_key "agave"

cat > config.toml<<EOF
# Drupot Configuration File

[drupal]
# Port to server the honeypot webserver on.
# Note: Ports under 1024 require sudo.
port = 80

site_name = "Nothing"
name_randomizer = true

# TODO: Optional SSL/TLS Cert

[hpfeeds]
enabled = true
host = "$HPF_HOST"
port = $HPF_PORT
ident = "$HPF_IDENT"
auth = "$HPF_SECRET"
channel = "agave.events"

[fetch_public_ip]
enabled = true
urls = ["http://icanhazip.com/", "http://ifconfig.me/ip"]

EOF

# Config for supervisor.
cat > /etc/supervisor/conf.d/drupot.conf <<EOF
[program:drupot]
command=/opt/drupot/drupot
directory=/opt/drupot
stdout_logfile=/opt/drupot/drupot.out
stderr_logfile=/opt/drupot/drupot.err
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
EOF

supervisorctl update
supervisorctl restart all

