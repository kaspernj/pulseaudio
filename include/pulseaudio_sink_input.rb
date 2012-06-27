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
    list = %x[pacmd list-sink-inputs]
    inputs = [] unless block_given?
    
    list.scan(/index: (\d+)/) do |match|
      input_id = match[0].to_i
      args = {:input_id => input_id}
      
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
end