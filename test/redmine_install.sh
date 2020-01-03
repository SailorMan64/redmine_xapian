#!/bin/bash
#
# This script is almost entirely built on the build script from redmine_backlogs
# Please see: https://github.com/backlogs/redmine_backlogs
#

if [[ -e "$HOME/.xapian.rc" ]]; then
    source "$HOME/.xapian.rc"
fi

export PATH_TO_PLUGINS=./plugins
export GENERATE_SECRET=generate_secret_token
export MIGRATE_PLUGINS=redmine:plugins:migrate
export REDMINE_GIT_REPO=git://github.com/redmine/redmine.git
export REDMINE_GIT_TAG=4.1-stable

clone_redmine()
{
  set -e # exit if clone fails
  rm -rf $PATH_TO_REDMINE
  git clone -b $REDMINE_GIT_TAG --depth=100 --quiet $REDMINE_GIT_REPO $PATH_TO_REDMINE
  cd $PATH_TO_REDMINE
  git checkout $REDMINE_GIT_TAG  
}

run_tests()
{
  # exit if tests fail
  set -e

  cd $PATH_TO_REDMINE 

  # Run tests within application
  bundle exec rake redmine:plugins:test:units NAME=redmine_xapian RAILS_ENV=test
  bundle exec rake redmine:plugins:test:functionals NAME=redmine_xapian RAILS_ENV=test
}

uninstall()
{
  set -e # exit if migrate fails

  cd $PATH_TO_REDMINE

  # clean up database
  bundle exec rake $MIGRATE_PLUGINS NAME=redmine_xapian VERSION=0 RAILS_ENV=test  
}

run_install()
{
  # Exit if install fails
  set -e

  # cd to redmine folder
  cd $PATH_TO_REDMINE
  echo current directory is `pwd`

  # Create a link to the Xapian plugin
  ln -sf $PATH_TO_XAPIAN $PATH_TO_PLUGINS/redmine_xapian
  
  # Install gems
  mkdir -p vendor/bundle

  # Copy database.yml
  cp $WORKSPACE/database.yml config/
  
  bundle install --path vendor/bundle

  # Run redmine database migrations
  bundle exec rake db:migrate RAILS_ENV=test --trace  

  # Load redmine database default data  
  bundle exec rake redmine:load_default_data REDMINE_LANG=en RAILS_ENV=test

  # Generate session store/secret token
  bundle exec rake $GENERATE_SECRET
  
  # Run Xapian database migrations
  bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=test  
}

while getopts :irtu opt
do case "$opt" in
  r) clone_redmine; exit 0;;
  i) run_install; exit 0;;
  t) run_tests; exit 0;;
  u) uninstall; exit 0;;
  [?]) echo "i: install; r: clone redmine; t: run tests; u: uninstall";;
  esac
done