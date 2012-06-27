require "wref"

#A framework for controlling various elements of PulseAudio in Ruby.
class PulseAudio
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.realpath("#{File.dirname(__FILE__)}/../include")}/pulseaudio_#{name.to_s.downcase}.rb"
    return PulseAudio.const_get(name)
  end
end