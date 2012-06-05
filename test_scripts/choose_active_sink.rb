#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/../lib/pulseaudio.rb"

cas = PulseAudio::Gui::Choose_active_sink.new
cas.ui["window"].signal_connect("destroy") do
  Gtk.main_quit
end

Gtk.main