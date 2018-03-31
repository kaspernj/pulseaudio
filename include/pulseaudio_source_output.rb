#Class for controlling outputs.
class PulseAudio::Source::Output
  @@outputs = Wref::Map.new
  
  #Starts automatically redirect new opened outputs to the default source.
  #===Examples
  # PulseAudio::Source::Output.auto_redirect_new_outputs_to_default_source
  def self.auto_redirect_new_outputs_to_default_source
    raise "Already redirecting!" if @auto_redirect_connect_id
    
    @auto_redirect_connect_id = PulseAudio::Events.instance.connect(:event => :new, :element => "source-output") do |data|
      begin
        source_output = PulseAudio::Source::Output.by_id(data[:args][:element_id])
        source_output.source = PulseAudio::Source.by_default
      rescue NameError
        #sometimes sources are killed instantly and we cant find them before that happens.
      end
    end
  end
  
  #Stops automatically redirecting new opened outputs to the default source.
  #===Examples
  # PulseAudio::Source::Output.stop_auto_redirect_new_outputs_to_default_source
  def self.stop_auto_redirect_new_outputs_to_default_source
    raise "Not redirecting at the moment." if !@auto_redirect_connect_id
    PulseAudio::Events.instance.unconnect(@auto_redirect_connect_id)
    @auto_redirect_connect_id = nil
  end
  
  #Returns a list of source-outputs.
  def self.list
    list = %x[pacmd list-source-outputs]
    
    outputs = [] unless block_given?
    
    list.scan(/index: (\d+)/) do |match|
      output_id = match[0].to_i
      args = {:output_id => output_id}
      
      output = @@outputs[output_id]
      if !output
        output = PulseAudio::Source::Output.new
        @@outputs[output_id] = output
      end
      
      output.update(args)
      
      if block_given?
        yield(output)
      else
        outputs << output
      end
    end
    
    if block_given?
      return nil
    else
      return outputs
    end
  end
  
  #Should not be called manually but through 'list'.
  def update(args)
    @args = args
  end
  
  #Returns the output-ID.
  def output_id
    return @args[:output_id]
  end
  
  #Moves the output to a new source.
  def source=(newsource)
    %x[pacmd move-source-output #{self.output_id} #{newsource.source_id}]
    return nil
  end
end