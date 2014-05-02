#!/bin/sh

export MOJO_MODE=production
export PLACK_ENV=production
export LC_ALL=en_US
export PATH=/opt/local/perl-5.16/bin:$PATH
APP_HOME=/var/lib/jpa/yapcasia.org/yapcasia2014-app

cd $APP_HOME
exec carton exec -Ilib -- $@
