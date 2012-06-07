#Subclass for gui elements.
class PulseAudio::Gui
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../gui/#{name.to_s.downcase}/#{name.to_s.downcase}.rb"
    return PulseAudio::Gui.const_get(name)
  end
end