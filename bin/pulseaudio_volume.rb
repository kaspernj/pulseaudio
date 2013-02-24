#!/usr/bin/env ruby1.9

require "rubygems"
require "#{File.dirname(__FILE__)}/../lib/pulseaudio.rb"

sinks = PulseAudio::Sink.list

if ARGV[0] == "up"
	next_vol = "-- +5%"
	sinks.each do |sink|
    sink.vol_incr if sink.active?
	end
elsif ARGV[0] == "down"
  sinks.each do |sink|
    sink.vol_decr if sink.active?
  end
elsif ARGV[0] == "mute"
  sinks.each do |sink|
    sink.mute_toggle if sink.active?
  end
else
  puts "Dont know what to do with argument: '#{ARGV[0]}'."
end