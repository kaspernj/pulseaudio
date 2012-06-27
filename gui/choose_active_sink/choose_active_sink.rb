class PulseAudio::Gui::Choose_active_sink
  attr_reader :ui
  
  def initialize
    require "gtk2"
    require "knjrbfw"
    
    @ui = Gtk::Builder.new.add("#{File.dirname(__FILE__)}/choose_active_sink.glade")
    @ui.connect_signals{|h| method(h)}
    
    #Init treeviews.
    Knj::Gtk2::Tv.init(@ui["tvSinks"], ["ID", "Name"])
    @ui["tvSinks"].columns[0].visible = false
    self.reload_sinks
    
    Knj::Gtk2::Tv.init(@ui["tvSources"], ["ID", "Name"])
    @ui["tvSources"].columns[0].visible = false
    self.reload_sources
    
    PulseAudio::Sink::Input.auto_redirect_new_inputs_to_default_sink
    PulseAudio::Source::Output.auto_redirect_new_outputs_to_default_source
    
    @ui["window"].show_all
  end
  
  def reload_sinks
    @reloading = true
    @ui["tvSinks"].model.clear
    PulseAudio::Sink.list do |sink|
      append_data = @ui["tvSinks"].append([sink.sink_id, sink.args[:props]["description"]])
      
      if sink.default?
        @ui["tvSinks"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def reload_sources
    @reloading = true
    
    @ui["tvSources"].model.clear
    PulseAudio::Source.list do |source|
      append_data = @ui["tvSources"].append([source.source_id, source.args[:props]["description"]])
      
      if source.default?
        @ui["tvSources"].selection.select_iter(append_data[:iter])
      end
    end
    
    @reloading = false
  end
  
  def on_tvSinks_cursor_changed
    return nil if @reloading
    sel = @ui["tvSinks"].sel
    return nil if !sel
    
    sink = nil
    PulseAudio::Sink.list do |sink_i|
      if sink_i.sink_id.to_i == sel[0].to_i
        sink = sink_i
        break
      end
    end
    
    raise "Could not find sink." if !sink
    sink.default!
  end
  
  def on_tvSources_cursor_changed
    return nil if @reloading
    sel = @ui["tvSources"].sel
    return nil if !sel
    
    source = nil
    PulseAudio::Source.list do |source_i|
      if source_i.source_id.to_i == sel[0].to_i
        source = source_i
        break
      end
    end
    
    raise "Could not find source." if !source
    source.default!
  end
end