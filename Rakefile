# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "pulseaudio"
  gem.homepage = "http://github.com/kaspernj/pulseaudio"
  gem.license = "MIT"
  gem.summary = %Q{Ruby-library for controlling PulseAudio.}
  gem.description = %Q{Ruby-library for controlling PulseAudio via 'pactl'.}
  gem.email = "k@spernj.org"
  gem.authors = ["Kasper Johansen"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

task :default => :spec
