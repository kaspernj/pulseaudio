#!/usr/bin/env ruby1.9

require "rubygems"
require "pulseaudio"

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
end