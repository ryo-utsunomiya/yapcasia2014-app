#!/usr/bin/env perl
use strict;
use lib "lib";
use Mojo::Server::PSGI;
use Plack::Middleware::Session;
use Plack::Builder;
use YAPC2013;

my $server = Mojo::Server::PSGI->new(app => YAPC2013->new);
my $psgi_app = $server->to_psgi_app;

builder {
    enable 'Session',
        state => $server->app->config->{'Session'}{'State'},
        store => $server->app->config->{'Session'}{'Store'},
    ;
    enable 'HTTPExceptions';
    $psgi_app;
};
