require 'net/ssh'
require 'net/ssh/gateway'

module Harvest
  class Connection
    attr_reader :ssh, :channel

    CR   = "\015"
    LF   = "\012"
    EOL  = CR + LF

    class TinyFactory
      def initialize(sock)
        @sock = sock
      end
      def open(host, port)
        s = @sock
        @sock = nil
        s
      end
    end

    def initialize(template, name, **opts, &blk) # :yield: mesg
      @name = name
      @opts = opts

      @max_retry         = opts[:max_retry] || 1
      @opts[:host_name]  ||= name
      @opts[:port]       ||= 22
      @opts[:prompt]     ||= /[$%#>] \z/n
      @opts[:timeout]    ||= 10
      @opts[:waittime]   ||= 0
      @opts[:terminator] ||= LF
      @opts[:ptyoptions] ||= {}
      @opts[:binmode]    ||= false
      @opts[:timeout]    ||= template.timeout

      @opts[:delegator]&.each do |name, bk|
        define_singleton_method(name, &bk)
      end

      if @opts[:relay]
        relay        = @opts[:relay]
        info         = Harvest.factory.inventory[relay]
        @opts[:port] = Net::SSH::Gateway.new(relay, nil, info)
      end

      unless (true == @opts[:binmode] or false == @opts[:binmode])
        raise ArgumentError, "Binmode option must be true or false"
      end

      if @opts[:proxy]
        opts = @opts.slice(:host, :port, :user, :password, :timeout)
        opts[:proxy] = TinyFactory.new(@opts[:proxy])

        @ssh = Net::SSH.start(nil, nil, opts)
        @close_all = true
      else
        logger("Trying " + @opts[:host] + "...\n", &blk)

        begin
          ssh_options = opts.slice(*Net::SSH::VALID_OPTIONS)
          @ssh        = Net::SSH.start(name, nil, ssh_options)
          @close_all  = true
        rescue TimeoutError
          raise TimeoutError, "timed out while opening a connection to the host"
        rescue
          logger($ERROR_INFO.to_s + "\n")
          raise
        end

        logger("Connected to " + @opts[:host] + ".\n")
      end

      start_ssh_connection
    rescue StandardError => err
      retry if (max_retry -= 1) > 0
      raise err
    end

    def start_ssh_connection
      @buf = ""
      @eof = false
      @channel = nil
      @ssh.open_channel do |channel|
        channel.on_data { |ch,data| @buf << data }
        channel.on_extended_data { |ch,type,data| @buf << data if type == 1 }
        channel.on_close { @eof = true }
        channel.request_pty(@opts[:ptyoptions]) { |ch,success|
          if success == false
            raise "Failed to open ssh pty"
          end
        }
        channel.send_channel_request("shell") { |ch, success|
          if success
            @channel = ch
            waitfor(&blk)
            return
          else
            raise "Failed to open ssh shell"
          end
        }
      end
      @ssh.loop
    end

    def close
      @channel.close if @channel
      @channel = nil
      @ssh.close if @close_all and @ssh
    end

    def binmode(mode = nil)
      case mode
      when nil
        @opts[:binmode]
      when true, false
        @opts[:binmode] = mode
      else
        raise ArgumentError, "argument must be true or false"
      end
    end

    def binmode=(mode)
      if (true == mode or false == mode)
        @opts[:binmode] = mode
      else
        raise ArgumentError, "argument must be true or false"
      end
    end

    def waitfor(prompt = @opts[:prompt], **opts) # :yield: recvdata
      opts[:timeout]  ||= @opts[:timeout]
      opts[:waittime] ||= @opts[:waittime]
      opts[:faileof]  ||= @opts[:faileof]
      prompt          = Regexp.new( Regexp.quote(prompt) ) if prompt.kind_of?(String)

      opts[:timeout] = nil unless opts[:timeout]

      line = ''
      buf  = ''
      rest = ''
      sock = @ssh.transport.socket

      until @ssh.transport.socket.available == 0 && @buf == "" && prompt === line && (@eof || (!sock.closed? && !IO::select([sock], nil, nil, opts[:waittime])))
        if @buf == '' && (@ssh.transport.socket.available == 0) && !(prompt === line) && !IO::select([sock], nil, nil, opts[:timeout])
          raise Net::ReadTimeout, "timed out while waiting for more data"
        end

        _process_ssh

        if @buf != ""
          c    = @buf; @buf = ""
          buf  = rest + c
          rest = ''

          unless @opts[:binmode]
            if pt = buf.rindex(/\r\z/no)
              buf  = buf[0 ... pt]
              rest = buf[pt .. -1]
            end
            buf.gsub!(/#{EOL}/no, "\n")
          end

          line += buf

          @log.print(buf) if @opts[:log]
          yield buf if block_given?

        elsif @eof # End of file reached
          break if prompt === line
          raise EOFError if opts[:faileof]
          if line == ''
            line = nil
            yield nil if block_given?
          end
          break
        end
      end
      line
    end

    def write(string)
      @channel.send_data string
      _process_ssh
    end

    def print(string)
      if @opts[:binmode]
        self.write(string)
      else
        self.write(string.gsub(/\n/n, @opts[:terminator]))
      end
    end

    def prompt= val
      @opts[:prompt] = val
    end

    def puts(string)
      self.print(string + "\n")
    end

    def cmd(string, **opts) # :yield: recvdata
      opts[:match]   ||= @opts[:prompt]
      opts[:timeout] ||= @opts[:timeout]
      opts[:faileof] ||= @opts[:faileof]

      self.puts(string)

      if block_given?
        waitfor(**opts){|c| yield c }
      else
        waitfor(**opts)
      end
    end

    private

    def logger(mes)
      yield mes if block_given?
      return    unless @opts[:log]

      unless @log
        @log =
          case file
          when IO     then file
          when String then File.open(file, 'a+')
          end
        @log.sync = true
        @log.binmode
      end

      @log.write(mes)
    end

    def _process_ssh
      begin
        @channel.connection.process(0)
      rescue IOError
        @eof = true
      end
    end

  end  # class Telnet
end  # module SSH
