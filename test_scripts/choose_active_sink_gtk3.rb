#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__))
require "../lib/pulseaudio.rb"

require "rubygems"
require "gir_ffi"
require "gir_ffi-gtk3"
require "/home/kaspernj/Dev/Ruby/Gems/knjrbfw/lib/knjrbfw.rb"
require "gettext"
Knj.gem_require(:Gtk3assist, "gtk3assist")

Gtk3assist.enable_threadding

def _(str)
  return GetText._(str)
end

Gtk.init

cas = PulseAudio::Gui::Choose_active_sink_gtk3.new
cas.ui["window"].signal_connect("destroy") do
  Gtk.main_quit
end

Gtk.main