#!/usr/bin/env ruby

require "#{File.realpath(File.dirname(__FILE__))}/../lib/pulseaudio.rb"

require "rubygems"
require "gir_ffi"
require "gir_ffi-gtk3"
require "gettext"

#Try to load development-version of 'knjrbfw'.
begin
  require "#{File.realpath(File.dirname(__FILE__))}/../../knjrbfw/lib/knjrbfw.rb"
rescue LoadError
  require "knjrbfw"
end

Knj.gem_require(:Gtk3assist, "gtk3assist")

Gtk3assist::Threadding.enable_threadding

def _(str)
  return GetText._(str)
end

Gtk.init

cas = PulseAudio::Gui::Choose_active_sink_gtk3.new
cas.ui["window"].signal_connect("destroy") do
  Gtk.main_quit
end

Gtk.main