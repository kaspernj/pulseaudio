#Class for controlling outputs.
class PulseAudio::Source::Output
  @@outputs = Wref_map.new
  
  #Returns a list of source-outputs.
  def self.list
    list = %x[pacmd list-source-outputs]
    
    outputs = [] unless block_given?
    
    list.scan(/index: (\d+)/) do |match|
      output_id = match[0].to_i
      args = {:output_id => output_id}
      
      output = @@outputs.get!(output_id)
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