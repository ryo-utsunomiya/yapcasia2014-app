use inc::Module::Install;

name 'YAPC2013';

all_from 'lib/YAPC2013.pm';
requires 'Mojolicious';
requires 'MojoX::Renderer::Xslate';
requires 'Plack::Session';
requires 'Cache::Memcached::Fast';
requires 'DBI';
requires 'Data::FormValidator';
requires 'Data::UUID';
requires 'Data::Localize';
requires 'Furl';
requires 'JSON';
requires 'HTML::Scrubber';
requires 'Text::Markdown';
requires 'Log::Minimal';
requires 'Starlet';
requires 'Server::Starter';
requires 'Plack';
requires 'Plack::Middleware::Session';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Exporter::Constants';
requires 'Teng';
requires 'Data::Dumper::Concise';
requires 'OAuth::Lite::Consumer';

WriteAll;

