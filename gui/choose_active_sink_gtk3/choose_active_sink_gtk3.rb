class PulseAudio::Gui::Choose_active_sink_gtk3
  attr_reader :ui
  
  def initialize
    @ui = Gtk3assist::Builder.new.add_from_file("#{File.dirname(__FILE__)}/choose_active_sink.glade")
    @ui.connect_signals{|h| method(h)}
    
    #Init treeviews.
    @tv_sinks = Gtk3assist::Treeview.new(
      :tv => @ui["tvSinks"],
      :model => :liststore,
      :sort_col => :name,
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
      :sort_col => :name,
      :cols => [
        {:id => :id, :title => _("ID")},
        {:id => :name, :title => _("Name")}
      ]
    )
    @ui["tvSources"].get_column(0).visible = false
    self.reload_sources
    
    PulseAudio::Sink::Input.auto_redirect_new_inputs_to_default_sink
    PulseAudio::Source::Output.auto_redirect_new_outputs_to_default_source
    
    events = PulseAudio::Events.instance
    events.connect(:event => :remove, &self.method(:on_remove))
    events.connect(:event => :new, &self.method(:on_new))
    
    @sicon = Gtk::StatusIcon.new
    @sicon.signal_connect("activate", &self.method(:on_sicon_activate))
    @sicon.signal_connect("popup-menu", &self.method(:on_sicon_popupmenu))
    @sicon.signal_connect("scroll-event", &self.method(:on_sicon_scroll))
    self.update_icon
  end
  
  #Called when the window-state is changed to close window instead of minimize.
  def on_window_window_state_event(win, win_state)
    if win_state.new_window_state == 130
      @ui["window"].hide
      @ui["window"].deiconify
    end
  end
  
  #Called when something is removed from PulseAudio. Removes items from the treeviews automatically.
  def on_remove(args)
    event, ele, ele_id = args[:args][:event].to_sym, args[:args][:element].to_s, args[:args][:element_id].to_i
    
    if ele == "sink"
      tv = @tv_sinks
    elsif ele == "source"
      tv = @tv_sources
    else
      return nil
    end
    
    tv.rows_remove do |data|
      if data[:data][:id].to_i == ele_id
        true
      else
        false
      end
    end
  end
  
  #Called when something is added to PulseAudio. Adds new items to the treeviews automatically.
  def on_new(args)
    event, ele, ele_id = args[:args][:event].to_sym, args[:args][:element].to_s, args[:args][:element_id].to_i
    
    if ele == "sink"
      sink = PulseAudio::Sink.by_id(ele_id.to_i)
      self.add_sink(sink)
    elsif ele == "source"
      source = PulseAudio::Source.by_id(ele_id.to_i)
      self.add_source(source)
    else
      return nil
    end
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
  
  def add_sink(sink)
    append_data = @tv_sinks.add_row(:data => {:id => sink.sink_id, :name => sink.args[:props]["description"]})
    return append_data
  end
  
  def reload_sinks
    @reloading = true
    @tv_sinks.model.clear
    PulseAudio::Sink.list do |sink|
      append_data = self.add_sink(sink)
      
      if sink.default?
        @ui["tvSinks"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def add_source(source)
    append_data = @tv_sources.add_row(:data => {:id => source.source_id, :name => source.args[:props]["description"]})
    return append_data
  end
  
  def reload_sources
    @reloading = true
    
    @tv_sources.model.clear
    PulseAudio::Source.list do |source|
      append_data = self.add_source(source)
      
      if source.default?
        @ui["tvSources"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def on_tvSinks_cursor_changed(*args)
    begin
      return nil if @reloading or !@tv_sinks
      sel = @tv_sinks.sel
      return nil if !sel
      puts sel
      
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
    rescue => e
      Gtk3assist::Msgbox.error(e)
    end
  end
  
  def on_tvSources_cursor_changed(*args)
    begin
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
    rescue => e
      Gtk3assist::Msgbox.error(e)
    end
  end
  
  def on_window_delete_event(*args)
    @ui["window"].hide
    return true
  end
end