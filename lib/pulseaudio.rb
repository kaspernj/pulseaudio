require "wref"

#A framework for controlling various elements of PulseAudio in Ruby.
class PulseAudio
end

dir = "#{File.dirname(__FILE__)}/../include"
files = []
Dir.foreach(dir) do |file|
  files << "#{dir}/#{file}" if file.match(/\.rb$/)
end

files.sort.each do |file|
  require file
end