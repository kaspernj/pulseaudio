class PulseAudio::Source
  #The arguments-hash. Contains various data for the source.
  attr_reader :args

  @@sources = Wref::Map.new
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

  #This automatically reloads a source when a 'change'-event appears.
  PulseAudio::Events.instance.connect(:event => :change, :element => "source") do |args|
    if @@sources.key?(args[:args][:element_id]) and source = @@sources.get!(args[:args][:element_id])
      source.reload
    end
  end

  #Reloads the information on the source.
  def reload
    PulseAudio::Source.list #Reloads info on all sources.
  end

  #Updates the data on the object. This should not be called.
  def update(args)
    @args = args
  end

  #Returns true if the source is muted. Otherwise false.
  #===Examples
  # source.muted? #=> false
  def muted?
    return true if @args[:props]["mute"] == "yes"
    return false
  end

  #Toggles the mute-functionality of the source. If it is muted: unmutes. If it isnt muted: mutes.
  #===Examples
  # source.mute_toggle #=> nil
  def mute_toggle
    self.mute = !self.muted?
    return nil
  end

  #Sets the mute to something specific.
  #===Examples
  # source.mute = true #=> nil
  def mute=(val)
    if val
      %x[pactl set-source-mute #{self.source_id} 1]
    else
      %x[pactl set-source-mute #{self.source_id} 0]
    end

    return nil
  end

  #Increases the volume of the source by 5%.
  #===Examples
  # source.vol_incr if source.active? #=> nil
  def vol_incr
    %x[pactl set-source-volume #{self.source_id} -- +5%]
    return nil
  end

  #Decreases the volume of the source by 5%.
  #===Examples
  # source.vol_decr if source.active? #=> nil
  def vol_decr
    %x[pactl set-source-volume #{self.source_id} -- -5%]
    return nil
  end

  def vol_perc=(newval)
    %x[pactl set-source-volume #{self.source_id} #{newval.to_i}%]
    return nil
  end

  #Returns the current percent of the volume.
  def vol_perc
    if match = @args[:props]["volume"].to_s.match(/(\d+):\s*(\d+)%/)
      return match[2].to_i
    end

    raise "Could not figure out the volume."
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