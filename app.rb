# This file contains your application, it requires dependencies and necessary
# parts of the application.
#
# It will be required from either `config.ru` or `start.rb`

require 'rubygems'
require 'ramaze'

Ramaze.options.roots = [__DIR__]

# Add the directory this file resides in to the load path, so you can run the
# app from any other working directory
$LOAD_PATH.unshift(__DIR__)

require "lib/config"
require "lib/error"

# Initialize controllers and models
require "model/coverage"
require 'controller/main'

Concov::Config.deploy("concov.conf")
