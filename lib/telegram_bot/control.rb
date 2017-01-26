require 'daemons'

Daemons.run("#{File.dirname(__FILE__)}/main.rb")
