#!/bin/sh

export MOJO_MODE=production
export PLACK_ENV=production
export LC_ALL=en_US
export PATH=/var/lib/jpa/perl5/perls/perl-5.14.2/bin:/var/lib/jpa/perl5/bin:$PATH
APP_HOME=/var/lib/jpa/yapcasia.org/yapcasia2013-app

cd $APP_HOME
carton exec -Ilib -- $@
