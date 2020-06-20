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

      max_retry  = opts[:max_retry] || 1
      opts[:delegator]&.each do |name, bk|
        define_singleton_method(name, &bk)
      end

      opts[:timeout]   ||= template.timeout
      opts[:host_name] ||= name

      begin
        args = {}
        args['Dump_log']    = opts[:dump_log]   if opts[:dump_log]
        args['Output_log']  = opts[:log]        if opts[:log]
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
  end
end
