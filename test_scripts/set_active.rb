#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/../lib/pulseaudio.rb"

look_for = nil
ARGV.each do |arg|
  if match = arg.match(/^--look_for=(.+)$/)
    look_for = match[1]
  end
end

raise "No '--look_for=[SOMETHING]' was given." if !look_for

sink = nil
PulseAudio::Sink.list do |sink_i|
  if sink_i.args[:props]["description"].index(look_for) != nil
    sink = sink_i
    break
  end
end

raise "Could not find the sink by: '#{look_for}'." if !sink

print "Setting '#{sink.args[:props]["description"]}'.\n"
sink.default!