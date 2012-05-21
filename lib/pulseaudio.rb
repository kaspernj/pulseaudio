#A framework for controlling various elements of PulseAudio in Ruby.
class PulseAudio
  #Class for controlling sinks. The sinks on the sytem can be gotten by running the list-method.
  #===Examples
  # sinks = PulseAudio::Sink.list
  # sinks.each do |sink|
  #   sink.vol_decr if sink.active?
  # end
  class Sink
    #The arguments-hash. Contains various data for the sink.
    attr_reader :args
    
    require "wref"
    @@sinks = Wref_map.new
    
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
        
        sink_id = match[1].to_i
        args = {:sink_id => sink_id, :props => props}
        
        sink = @@sinks.get!(sink_id)
        if !sink
          sink = PulseAudio::Sink.new
          @@sinks[sink_id] = sink
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
      
      PulseAudio::Sink.list #reload info.
      return nil
    end
    
    #Increases the volume of the sink by 5%.
    #===Examples
    # sink.vol_incr if sink.active? #=> nil
    def vol_incr
      %x[pactl set-sink-volume #{self.sink_id} -- +5%]
      PulseAudio::Sink.list #reload info.
      return nil
    end
    
    #Decreases the volume of the sink by 5%.
    #===Examples
    # sink.vol_decr if sink.active? #=> nil
    def vol_decr
      %x[pactl set-sink-volume #{self.sink_id} -- -5%]
      PulseAudio::Sink.list #reload info.
      return nil
    end
  end
end