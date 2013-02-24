#!/usr/bin/env ruby

#Try to load development-version of 'knjrbfw'.
begin
  require "#{File.realpath(File.dirname(__FILE__))}/../../knjrbfw/lib/knjrbfw.rb"
  puts "Loaded custom knjrbfw."
rescue LoadError
  require "knjrbfw"
end

Knj.gem_require([:wref, :gtk3assist, :autogc])

require "#{File.realpath(File.dirname(__FILE__))}/../lib/pulseaudio.rb"

require "rubygems"
require "gir_ffi"
require "gir_ffi-gtk3"
require "gettext"

#Solves memory corruption problem in Ruby 1.9.3.
Autogc.enable_for_known_buggy_env

#Solves threadding issues with Gir-GTK and MRI Ruby.
Gtk3assist::Threadding.enable_threadding_if_necessary

#Shortcut for GetText.
def _(str)
  return GetText._(str)
end

Gtk.init

cas = PulseAudio::Gui::Choose_active_sink_gtk3.new
cas.ui["window"].signal_connect("destroy") do
  Gtk.main_quit
end

Gtk.main