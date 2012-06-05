class PulseAudio::Gui::Choose_active_sink
  attr_reader :ui
  
  def initialize
    require "gtk2"
    require "knjrbfw"
    
    @ui = Gtk::Builder.new.add("#{File.dirname(__FILE__)}/choose_active_sink.glade")
    @ui.connect_signals{|h| method(h)}
    
    #Init treeview.
    Knj::Gtk2::Tv.init(@ui["tvSinks"], ["ID", "Name"])
    @ui["tvSinks"].columns[0].visible = false
    self.reload_sinks
    
    @ui["window"].show_all
  end
  
  def reload_sinks
    @ui["tvSinks"].model.clear
    PulseAudio::Sink.list do |sink|
      @ui["tvSinks"].append([sink.sink_id, sink.args[:props]["description"]])
    end
  end
  
  def on_tvSinks_cursor_changed
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
end