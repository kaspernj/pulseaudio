#Class for controlling inputs.
class PulseAudio::Sink::Input
  @@inputs = Wref_map.new
  
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