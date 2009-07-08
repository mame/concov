#!/usr/bin/env rackup
#
# config.ru for ramaze apps
# use thin >= 1.0.0
# thin start -R config.ru
#
# rackup is a useful tool for running Rack applications, which uses the
# Rack::Builder DSL to configure middleware and build up applications easily.
#
# rackup automatically figures out the environment it is run in, and runs your
# application as FastCGI, CGI, or standalone with Mongrel or WEBrick -- all from
# the same configuration.
#
# Do not set the adapter.handler in here, it will be ignored.
# You can choose the adapter like `ramaze start -s mongrel` or set it in the
# 'start.rb' and use `ruby start.rb` instead.

require ::File.expand_path('../app', __FILE__)

Ramaze.middleware :deflate do |mw|
  mw.use Rack::Lint
  mw.use Rack::CommonLogger, Ramaze::Log
  mw.use Rack::ShowStatus
  mw.use Rack::RouteExceptions
  mw.use Rack::ContentLength
  mw.use Rack::ConditionalGet
  mw.use Rack::ETag
  mw.use Rack::Head
  mw.use Rack::Deflater
  mw.use Ramaze::Reloader
  mw.run Ramaze::AppMap
end

Ramaze.middleware :deflate_live do |mw|
  mw.use Rack::CommonLogger, Ramaze::Log
  mw.use Rack::RouteExceptions
  mw.use Rack::ShowStatus
  mw.use Rack::ContentLength
  mw.use Rack::ConditionalGet
  mw.use Rack::ETag
  mw.use Rack::Head
  mw.use Rack::Deflater
  mw.run Ramaze::AppMap
end

Ramaze.start(:root => __DIR__, :started => true, :mode => :deflate_live, :port => 7001)
run Ramaze
