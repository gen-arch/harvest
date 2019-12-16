# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/telnet'
require 'net/ssh/gateway'

module Harvest
  class Connection < Net::SSH::Telnet
    attr_reader :name
    attr_reader :delegator

    def initialize(template, name, **opts)
      @name = name

      @logs      = log_format(opts[:log] || opts[:output_log])
      max_retry  = opts[:max_retry] || 1
      opts[:delegator]&.each do |name, bk|
        define_singleton_method(name, &bk)
      end

      opts[:timeout]   ||= template.timeout
      opts[:host_name] ||= name

      begin
        args = {}
        args['Dump_log']    = opts[:dump_log]   if opts[:dump_log]
        args['Prompt']      = opts[:prompt]     || template.prompt_patten
        args['Timeout']     = opts[:timeout]    || 10
        args['Waittime']    = opts[:waittime]   || 0
        args['Terminator']  = opts[:terminator] || LF
        args['Binmode']     = opts[:binmode]    || false
        args['PTYOptions']  = opts[:ptyoptions] || {}

        if opts[:relay]
          relay             = opts[:relay]
          info              = Harvest.factory.inventory[relay]
          opts[:port] = Net::SSH::Gateway.new(relay, nil, info)
        end

        if opts[:proxy]
          args['Host']      = opts[:host_name]
          args['Port']      = opts[:port]
          args['Username']  = opts[:user]
          args['Password']  = opts[:password]
          args['Proxy']     = opts[:proxy]
        else
          ssh_options       = opts.slice(*Net::SSH::VALID_OPTIONS)
          args['Session']   = Net::SSH.start(name, nil, ssh_options)
        end

        super(args)
      rescue StandardError => e
        retry if (max_retry -= 1) > 0
        raise e
      end
    end

    def waitfor(options) # :yield: recvdata
      time_out = @options['Timeout']
      waittime = @options['Waittime']
      fail_eof = @options['FailEOF']

      if options.is_a?(Hash)
        prompt   = if options.key?('Match')
                     options['Match']
                   elsif options.key?('Prompt')
                     options['Prompt']
                   elsif options.key?('String')
                     Regexp.new(Regexp.quote(options['String']))
                   end
        time_out = options['Timeout']  if options.key?('Timeout')
        waittime = options['Waittime'] if options.key?('Waittime')
        fail_eof = options['FailEOF']  if options.key?('FailEOF')
      else
        prompt = options
      end

      time_out = nil if time_out == false

      line = ''
      buf = ''
      rest = ''
      sock = @ssh.transport.socket

      until @ssh.transport.socket.available == 0 && @buf == '' && prompt === line && (@eof || (!sock.closed? && !IO.select([sock], nil, nil, waittime)))
        # @buf may have content if it was processed by Net::SSH before #waitfor
        # was called
        # The prompt is checked in case a waittime was specified, we've already
        # seen the prompt, but a protocol-level packet came through during the
        # above IO::select, causing us to reprocess
        if @buf == '' && (@ssh.transport.socket.available == 0) && !(prompt === line) && !IO.select([sock], nil, nil, time_out)
          raise Net::ReadTimeout, 'timed out while waiting for more data'
        end

        _process_ssh
        if @buf != ''
          c = @buf; @buf = ''
          @dumplog.log_dump('<', c) if @options.key?('Dump_log')
          buf = rest + c
          rest = ''
          unless @options['Binmode']
            if pt = buf.rindex(/\r\z/no)
              buf = buf[0...pt]
              rest = buf[pt..-1]
            end
            buf.gsub!(/#{EOL}/no, "\n")
          end

          @log.print(buf) if @options.key?('Output_log')
          @logs&.each do |log|
            log.print(buf)
          end

          line += buf
          yield buf if block_given?
        elsif @eof # End of file reached
          break if prompt === line
          raise EOFError if fail_eof

          if line == ''
            line = nil
            yield nil if block_given?
          end
          break
        end
      end
      line
    end

    def log_format(log)
      return [] unless log

      logs = log.is_a?(Array) ? log : [log]

      logs.map do |log|
        case log
        when String
          open(log, 'a+') if File.exist?(log)
        when IO
          log
        end
      end
    end
  end
end
