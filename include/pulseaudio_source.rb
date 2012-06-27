class PulseAudio::Source
  #The arguments-hash. Contains various data for the source.
  attr_reader :args
  
  @@sources = Wref_map.new
  @@sources_name_to_id_ref = {}
  
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.realpath(File.dirname(__FILE__))}/pulseaudio_source_#{name.to_s.downcase}.rb"
    return PulseAudio::Source.const_get(name)
  end
  
  def self.list
    list = %x[pactl list sources]
    sources = [] unless block_given?
    
    list.scan(/(\n|^)Source #(\d+)\s+([\s\S]+?)Formats:\s+(.+?)\n/) do |match|
      props = {}
      match[2].scan(/(\t|^)([A-z]+?): (.+?)\n/) do |match_prop|
        props[match_prop[1].downcase] = match_prop[2]
      end
      
      source_id = match[1].to_i
      args = {:source_id => source_id, :props => props}
      
      source = @@sources.get!(source_id)
      if !source
        source = PulseAudio::Source.new
        @@sources[source_id] = source
        @@sources_name_to_id_ref[props["name"]] = source_id
      end
      
      source.update(args)
      
      if block_given?
        yield(source)
      else
        sources << source
      end
    end
    
    if block_given?
      return nil
    else
      return sources
    end
  end
  
  #Returns the default source by doing a smart lookup and using the 'name-to-id-ref'-cache.
  def self.by_default
    def_str = %x[pacmd info | grep "Default source name"]
    raise "Could not match default source." if !match = def_str.match(/^Default source name: (.+?)\s*$/)
    source_id = @@sources_name_to_id_ref[match[1]]
    raise "Could not figure out source-ID." if !source_id
    return PulseAudio::Source.by_id(source_id.to_i)
  end
  
  #Returns a source by its source-ID.
  #===Examples
  # source = PulseAudio::Source.by_id(3)
  def self.by_id(id)
    #Return it from the weak-reference-map, if it already exists there.
    if source = @@sources.get!(id)
      return source
    end
    
    #Read the sources one-by-one and return it when found.
    PulseAudio::Source.list do |source|
      return source if source.source_id == id
    end
    
    #Source could not be found by the given ID - raise error.
    raise NameError, "No source by that ID: '#{id}' (#{id.class.name})."
  end
  
  #Updates the data on the object. This should not be called.
  def update(args)
    @args = args
  end
  
  #Returns the ID of the source.
  #===Examples
  # source.source_id #=> 2
  def source_id
    return @args[:source_id].to_i
  end
  
  #Returns true if this source is the default one.
  def default?
    def_str = %x[pacmd info | grep "Default source name"]
    raise "Could not match default source." if !match = def_str.match(/^Default source name: (.+?)\s*$/)
    return true if @args[:props]["name"] == match[1]
  end
  
  #Sets this source to be the default one. Also moves all outputs to this source.
  #===Examples
  # source.default!
  def default!
    PulseAudio::Source::Output.list do |output|
      output.source = self
    end
    
    %x[pacmd set-default-source #{self.source_id}]
    return nil
  end
end