set -e

# cd straight to /vagrant on login
if ! grep -q 'cd \/vagrant' /home/vagrant/.bashrc; then
  echo 'cd /vagrant' >> /home/vagrant/.bashrc
fi
cd /vagrant

# Install dependencies
sudo apt-add-repository -y ppa:brightbox/ruby-ng
sudo apt-get update --quiet
sudo apt-get install -y ruby2.2 ruby2.2-dev git python-boto s3cmd
sudo gem install bundler
bundle install
