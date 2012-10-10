#Class for controlling inputs.
class PulseAudio::Sink::Input
  @@inputs = Wref_map.new
  
  #Starts automatically redirect new opened inputs to the default sink.
  #===Examples
  # PulseAudio::Sink::Input.auto_redirect_new_inputs_to_default_sink
  def self.auto_redirect_new_inputs_to_default_sink
    raise "Already redirecting!" if @auto_redirect_connect_id
    
    @auto_redirect_connect_id = PulseAudio::Events.instance.connect(:event => :new, :element => "sink-input") do |data|
      begin
        sink_input = PulseAudio::Sink::Input.by_id(data[:args][:element_id])
        sink_input.sink = PulseAudio::Sink.by_default
      rescue NameError
        #sometimes sinks are killed instantly and we cant find them before that happens.
      end
    end
  end
  
  #Stops automatically redirecting new opened inputs to the default sink.
  #===Examples
  # PulseAudio::Sink::Input.stop_auto_redirect_new_inputs_to_default_sink
  def self.stop_auto_redirect_new_inputs_to_default_sink
    raise "Not redirecting at the moment." if !@auto_redirect_connect_id
    PulseAudio::Events.instance.unconnect(@auto_redirect_connect_id)
    @auto_redirect_connect_id = nil
  end
  
  #Returns a list of sink-inputs.
  def self.list
    list = %x[pactl list sink-inputs]
    inputs = [] unless block_given?
    
    list.scan(/(\n|^)Sink Input #(\d+)\s+([\s\S]+?)(\n\n|\Z)/) do |match|
      props = {}
      match[2].scan(/(\s+|^)([A-z]+?): (.+?)\n/) do |match_prop|
        props[match_prop[1].downcase] = match_prop[2]
      end

      match[2].scan(/(\t\t|^)([A-z\.]+?) = (.+?)\n/) do |match_prop|
        props[match_prop[1].downcase.gsub(/\./, "_")] = match_prop[2].gsub(/\"/, "")
      end

      input_id = match[1].to_i
      args = {:input_id => input_id, :props => props}

      input = @@inputs.get!(input_id)
      if !input
        input = PulseAudio::Sink::Input.new
        @@inputs[input_id] = input
      end

      input.update(args)

      if block_given?
        yield(input)
      else
        inputs << input
      end
    end
    
    if block_given?
      return nil
    else
      return inputs
    end
  end
  
  #Returns a sink-input by its input-ID.
  #===Examples
  # sink_input = PulseAudio::Sink::Input.by_id(53)
  def self.by_id(id)
    #Return it from the weak-reference-map, if it already exists there.
    if input = @@inputs.get!(id)
      return input
    end
    
    #Read the inputs one-by-one and return it when found.
    PulseAudio::Sink::Input.list do |input|
      return input if input.input_id == id
    end
    
    #Input could not be found by the given ID - raise error.
    raise NameError, "No sink-input by that ID: '#{id}' (#{id.class.name})."
  end
  
  #Should not be called manually but through 'list'.
  def update(args)
    @args = args
  end
  
  #Returns the input-ID.
  def input_id
    return @args[:input_id]
  end
  
  #Moves the output to a new sink.
  def sink=(newsink)
    %x[pacmd move-sink-input #{self.input_id} #{newsink.sink_id}]
    return nil
  end
  
  #Returns true if the sink is muted. Otherwise false.
  #===Examples
  # sink.muted? #=> false
  def muted?
    @args[:props]["mute"] == "yes"
  end
  
  #Toggles the mute-functionality of the sink. If it is muted: unmutes. If it isnt muted: mutes.
  #===Examples
  # sink.mute_toggle #=> nil
  def mute_toggle
    self.mute = !self.muted?
    return nil
  end
  
  #Sets the mute to something specific.
  #===Examples
  # sink.mute = true #=> nil
  def mute=(val)
    if val
      %x[pactl set-sink-input-mute #{self.input_id} 1]
      @args[:props]["mute"] = "yes"
    else
      %x[pactl set-sink-input-mute #{self.input_id} 0]
      @args[:props]["mute"] = "no"
    end
    
    return nil
  end
  
  #Increases the volume of the sink by 5%.
  #===Examples
  # sink.vol_incr if sink.active? #=> nil
  def vol_incr
    %x[pactl set-sink-input-volume #{self.input_id} -- +5%]
    new_vol = vol_perc + 5
    new_vol = 100 if new_vol > 100
    @args[:props]["volume"] = "0:  #{new_vol}% 1:  #{new_vol}%"
    return nil
  end
  
  #Decreases the volume of the sink by 5%.
  #===Examples
  # sink.vol_decr if sink.active? #=> nil
  def vol_decr
    %x[pactl set-sink-input-volume #{self.input_id} -- -5%]
    new_vol = vol_perc - 5
    new_vol = 0 if new_vol < 0
    @args[:props]["volume"] = "0:  #{new_vol}% 1:  #{new_vol}%"
    return nil
  end
  
  def vol_perc=(newval)
    %x[pactl set-sink-input-volume #{self.input_id} #{newval.to_i}%]
    @args[:props]["volume"] = "0:  #{newval}% 1:  #{newval}%"
    return nil
  end
  
  #Returns the current percent of the volume.
  def vol_perc
    if match = @args[:props]["volume"].to_s.match(/(\d+):\s*(\d+)%/)
      return match[2].to_i
    end
    
    raise "Could not figure out the volume."
  end

  def method_missing(meth, *args, &block)
    @args[:props][meth.to_s]
  end
end