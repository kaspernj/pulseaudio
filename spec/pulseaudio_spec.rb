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

  it "should spawn sink inputs and manipulate them" do
    PulseAudio::Sink::Input.list do |input|
      input.vol_decr
      input.vol_incr
      input.mute_toggle
      input.mute_toggle
    end
  end
  
  it "should be able to listen for events and redirect all new inputs to the default sink" do
    def_sink = nil
    PulseAudio::Sink.list do |sink|
      if sink.default?
        def_sink = sink
        break
      end
    end
    
    PulseAudio::Sink::Input.auto_redirect_new_inputs_to_default_sink
    PulseAudio::Events.instance.join
  end
end
