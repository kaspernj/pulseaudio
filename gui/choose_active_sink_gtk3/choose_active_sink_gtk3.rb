class PulseAudio::Gui::Choose_active_sink_gtk3
  attr_reader :ui
  
  def initialize
    @ui = Gtk3assist::Builder.new.add_from_file("#{File.dirname(__FILE__)}/choose_active_sink.glade")
    @ui.connect_signals{|h| method(h)}
    
    #Init treeviews.
    @tv_sinks = Gtk3assist::Treeview.new(
      :tv => @ui["tvSinks"],
      :model => :liststore,
      :cols => [
        {:id => :id, :title => _("ID")},
        {:id => :name, :title => _("Name")}
      ]
    )
    @ui["tvSinks"].get_column(0).visible = false
    self.reload_sinks
    
    @tv_sources = Gtk3assist::Treeview.new(
      :tv => @ui["tvSources"],
      :model => :liststore,
      :cols => [_("ID"), _("Name")]
    )
    @ui["tvSources"].get_column(0).visible = false
    self.reload_sources
    
    PulseAudio::Sink::Input.auto_redirect_new_inputs_to_default_sink
    PulseAudio::Source::Output.auto_redirect_new_outputs_to_default_source
    
    @sicon = Gtk::StatusIcon.new
    @sicon.signal_connect("activate", &self.method(:on_sicon_activate))
    @sicon.signal_connect("popup-menu", &self.method(:on_sicon_popupmenu))
    @sicon.signal_connect("scroll-event", &self.method(:on_sicon_scroll))
    self.update_icon
  end
  
  #Updates the statusicons icon based on the current sinks volume.
  def update_icon
    #Get the current active sink which should be manipulated.
    sink_def = PulseAudio::Sink.by_default
    return nil if !sink_def
    
    
    #Evaluate which icon is the closest to the current volume.
    vol_perc = sink_def.vol_perc
    levels = [0, 33, 66, 100]
    
    vol_closest = levels.first
    vol_closest_dif = 100
    
    levels.each do |level|
      if !vol_closest or (vol_perc < level and diff = (level - vol_perc) and diff < vol_closest_dif) or (vol_perc >= level and diff = (vol_perc - level) and diff < vol_closest_dif)
        vol_closest = level
        vol_closest_dif = diff
      end
    end
    
    
    #Set icon.
    icon_filepath = File.realpath("#{File.dirname(__FILE__)}/../../gfx/volume_#{vol_closest}.png")
    @sicon.set_from_file(icon_filepath)
  end
  
  def on_sicon_activate(*args)
    if !@ui["window"].get_visible
      @ui["window"].show_all
    else
      @ui["window"].hide
    end
  end
  
  def on_sicon_scroll(sicon, scroll_e, temp)
    direction = scroll_e.direction.to_s
    return nil if direction == "smooth"
    sink_def = PulseAudio::Sink.by_default
    
    if direction == "up"
      sink_def.vol_incr
    elsif direction == "down"
      sink_def.vol_decr
    end
    
    self.update_icon
  end
  
  def on_sicon_popupmenu(*args)
    Gtk.main_quit
  end
  
  def reload_sinks
    @reloading = true
    @tv_sinks.model.clear
    PulseAudio::Sink.list do |sink|
      append_data = @tv_sinks.add_row(:data => {:id => sink.sink_id, :name => sink.args[:props]["description"]})
      
      if sink.default?
        @ui["tvSinks"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def reload_sources
    @reloading = true
    
    @tv_sources.model.clear
    PulseAudio::Source.list do |source|
      append_data = @tv_sources.add_row(:data => {:id => source.source_id, :name => source.args[:props]["description"]})
      
      if source.default?
        @ui["tvSources"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def on_tvSinks_cursor_changed(*args)
    return nil if @reloading or !@tv_sinks
    sel = @tv_sinks.sel
    return nil if !sel
    
    sink = nil
    PulseAudio::Sink.list do |sink_i|
      if sink_i.sink_id.to_i == sel[:data][:id].to_i
        sink = sink_i
        break
      end
    end
    
    raise "Could not find sink." if !sink
    sink.default!
    self.update_icon
  end
  
  def on_tvSources_cursor_changed(*args)
    return nil if @reloading or !@tv_sources
    sel = @tv_sources.sel
    return nil if !sel
    
    source = nil
    PulseAudio::Source.list do |source_i|
      if source_i.source_id.to_i == sel[:data][:id].to_i
        source = source_i
        break
      end
    end
    
    raise "Could not find source." if !source
    source.default!
    self.update_icon
  end
  
  def on_window_delete_event(*args)
    @ui["window"].hide
    return true
  end
end