#This class listens for PulseAudio events, which you are able to connect to.
#===Examples
# events = PulseAudio::Events.instance
# events.connect(:event => :new, :element => "sink-input") do |data|
#   print "New event: #{data}\n"
# end
class PulseAudio::Events
  @@events_instance = nil
  
  #Returns the default instance of events - only one can exist!
  def self.instance
    @@events_instance = PulseAudio::Events.new if !@@events_instance
    return @@events_instance
  end
  
  def initialize(args = {})
    raise "An instance already exists." if @@events_instance
    
    @args = args
    @connects = {}
    @connects_count = 0
    @connects_mutex = Mutex.new
    require "open3"
    
    @thread = Thread.new do
      begin
        #Has to be done via PTY, since "pactl subscribe" requires a tty to write to...
        require "pty"
        PTY.spawn("pactl subscribe") do |stdout, stdin, pid|
          @pid = pid
          
          #Make sure destroy is called, when the process stops - else it might freeze.
          Kernel.at_exit do
            self.destroy
          end
          
          stdout.sync = true
          stdout.each_line do |line|
            if match = line.match(/^Event '(.+)' on (.+) #(\d+)/)
              event = match[1].to_sym
              element = match[2]
              element_id = match[3].to_i
              
              self.call(:event => event, :element => element, :element_id => element_id)
            else
              $stderr.puts "PulseAudio::Events thread could not unstand: '#{line}'."
            end
          end
        end
      rescue => e
        if !@args
          #ignore - this means the process has been killed.
        else
          $stderr.puts "An error occurred in the PulseAudio::Events thread!"
          $stderr.puts e.inspect
          $stderr.puts e.backtrace
        end
      end
    end
  end
  
  def destroy
    print "Destroy called!\n"
    @args = nil
    @connects = nil
    Process.kill("HUP", @pid) if @pid
    @@events_instance = nil
  end
  
  def connect(args, &block)
    raise "'args' wasnt a hash." if !args.is_a?(Hash)
    
    @connects_mutex.synchronize do
      id = @connects_count
      @connects_count += 1
      @connects[id] = {:args => args, :block => block}
      
      return {:connect_id => id}
    end
  end
  
  def unconnect(args)
    @connects_mutex.synchronize do
      raise "No connection by that ID: '#{args[:connect_id]}'." if !@connects.key?(args[:connect_id])
      @connects.delete(args[:connect_id])
    end
  end
  
  def call(args)
    @connects_mutex.synchronize do
      @connects.each do |id, connect_data|
        call = true
        
        connect_data[:args].each do |key, val|
          if !args.key?(key) or args[key] != val
            call = false
            break
          end
        end
        
        if call
          connect_data[:block].call(:args => args)
        end
      end
    end
  end
  
  def join
    @thread.join if @thread
  end
end