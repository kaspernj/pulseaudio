require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Pulseaudio" do
  it "should spawn sinks and manipulate them" do
    PulseAudio::Sink.list do |sink|
      sink.vol_decr
      sink.vol_incr
      sink.mute_toggle
      sink.mute_toggle
    end
  end
end
