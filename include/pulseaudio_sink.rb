#Class for controlling sinks. The sinks on the sytem can be gotten by running the list-method.
#===Examples
# sinks = PulseAudio::Sink.list
# sinks.each do |sink|
#   sink.vol_decr if sink.active?
# end
class PulseAudio::Sink
  #The arguments-hash. Contains various data for the sink.
  attr_reader :args
  
  @@sinks = Wref_map.new
  
  #Used to look up IDs from names (like when getting default sink).
  @@sink_name_to_id_ref = {}
  
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.realpath(File.dirname(__FILE__))}/pulseaudio_sink_#{name.to_s.downcase}.rb"
    return PulseAudio::Sink.const_get(name)
  end
  
  #Returns a list of sinks on the system. It also reloads information for all sinks if the information has been changed.
  #===Examples
  # sinks = PulseAudio::Sink.list
  # sinks.each do |sink|
  #   sink.vol_decr if sink.active?
  # end
  def self.list
    list = %x[pactl list sinks]
    sinks = [] unless block_given?
    
    list.scan(/(\n|^)Sink #(\d+)\s+([\s\S]+?)Formats:\s+(.+?)\n/) do |match|
      props = {}

      match[2].scan(/(\t|^)([A-z]+?): (.+?)\n/) do |match_prop|
        props[match_prop[1].downcase] = match_prop[2]
      end

      internal_props = {}
      sink_internal_properties = match[2].scan(/Properties:\n(?:.+=.+\n)+/).first
      sink_internal_properties.scan(/\t([A-z]+(?:\.[A-z]+)+) = "(.+?)"\n/) do |match_prop|
        internal_props[match_prop[0].downcase] = match_prop[1]
      end
      
      props["internal_props"] = internal_props

      sink_id = match[1].to_i
      args = {:sink_id => sink_id, :props => props}
      
      sink = @@sinks.get!(sink_id)
      if !sink
        sink = PulseAudio::Sink.new
        @@sinks[sink_id] = sink
        @@sink_name_to_id_ref[props["name"]] = sink_id
      end
      
      sink.update(args)
      
      if block_given?
        yield(sink)
      else
        sinks << sink
      end
    end
    
    if block_given?
      return nil
    else
      return sinks
    end
  end
  
  #Returns the default sink by doing a smart lookup and using the 'name-to-id-ref'-cache.
  def self.by_default
    def_str = %x[pacmd info | grep "Default sink name"]
    raise "Could not match default sink." if !match = def_str.match(/^Default sink name: (.+?)\s*$/)
    sink_id = @@sink_name_to_id_ref[match[1]]
    raise "Could not figure out sink-ID." if !sink_id
    return PulseAudio::Sink.by_id(sink_id.to_i)
  end
  
  #This automatically reloads a sink when a 'change'-event appears.
  PulseAudio::Events.instance.connect(:event => :change, :element => "sink") do |args|
    if @@sinks.key?(args[:args][:element_id]) and sink = @@sinks.get!(args[:args][:element_id])
      sink.reload
    end
  end
  
  #Reloads the information on the sink.
  def reload
    PulseAudio::Sink.list #Reloads information on all sinks.
  end
  
  #Returns a sink by its sink-ID.
  #===Examples
  # sink = PulseAudio::Sink.by_id(3)
  def self.by_id(id)
    #Return it from the weak-reference-map, if it already exists there.
    if sink = @@sinks.get!(id)
      return sink
    end
    
    #Read the sinks one-by-one and return it when found.
    PulseAudio::Sink.list do |sink|
      return sink if sink.sink_id == id
    end
    
    #Sink could not be found by the given ID - raise error.
    raise NameError, "No sink by that ID: '#{id}' (#{id.class.name})."
  end
  
  #Updates the data on the object. This should not be called.
  def update(args)
    @args = args
  end
  
  #Returns the ID of the sink.
  #===Examples
  # sink.sink_id #=> 2
  def sink_id
    return @args[:sink_id].to_i
  end
  
  #Returns true if the sink is active. Otherwise false.
  #===Examples
  # sink.active? #=> true
  def active?
    return true if @args[:props]["state"].to_s.downcase == "running"
    return false
  end
  
  #Returns true if the sink is muted. Otherwise false.
  #===Examples
  # sink.muted? #=> false
  def muted?
    return true if @args[:props]["mute"] == "yes"
    return false
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
      %x[pactl set-sink-mute #{self.sink_id} 1]
    else
      %x[pactl set-sink-mute #{self.sink_id} 0]
    end
    
    return nil
  end
  
  #Increases the volume of the sink by 5%.
  #===Examples
  # sink.vol_incr if sink.active? #=> nil
  def vol_incr
    %x[pactl set-sink-volume #{self.sink_id} -- +5%]
    return nil
  end
  
  #Decreases the volume of the sink by 5%.
  #===Examples
  # sink.vol_decr if sink.active? #=> nil
  def vol_decr
    %x[pactl set-sink-volume #{self.sink_id} -- -5%]
    return nil
  end
  
  def vol_perc=(newval)
    %x[pactl set-sink-volume #{self.sink_id} #{newval.to_i}%]
    return nil
  end
  
  #Returns the current percent of the volume.
  def vol_perc
    if match = @args[:props]["volume"].to_s.match(/(\d+):\s*(\d+)%/)
      return match[2].to_i
    end
    
    raise "Could not figure out the volume."
  end
  
  #Returns true if this sink is the default one.
  def default?
    def_str = %x[pacmd info | grep "Default sink name"]
    raise "Could not match default sink." if !match = def_str.match(/^Default sink name: (.+?)\s*$/)
    return true if @args[:props]["name"] == match[1]
  end
  
  #Sets this sink to be the default one. Also moves all inputs to this sink.
  #===Examples
  # sink.default!
  def default!
    #Set all inputs to the this sink.
    PulseAudio::Sink::Input.list do |input|
      input.sink = self
    end
    
    %x[pacmd set-default-sink #{self.sink_id}]
    return nil
  end
end
