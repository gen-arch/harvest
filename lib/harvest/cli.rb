require 'optparse'
require 'parallel'
require 'stringio'

module Harvest
  class CLI

    DEFAULT_INVENTORY = File.join(ENV['HOME'], '.harvestrc')
    DEFAULT_TEMPLATE  = File.join(ENV['HOME'], '.harvest.d')

    def self.run(args = ARGV)
      Harvest::CLI.new.run(args)
    end

    def hello
      puts "hello"
    end

    def list(config)
      puts Harvest.list(name: config[:name]).map{ |e| e[:name] }.sort.uniq
    end

    def tty(config)
      info = Harvest.find(name: config[:name])
      puts "Trying #{info[:name]}...", "Escape character is '^]'."

      session, _ = exec(config.merge(patterns: info[:name], jobs: 1))
      session.interact!
    end

    def exec(config)
      Signal.trap(:INT){ exit 1 }

      info  = Harvest.find(name: config[:name])
      width = info[:name].length
      raise "No host found: `#{info[:name]}`" if info.empty?

      buffer  = StringIO.new
      prefix  = "#{info[:name].to_s.ljust(width)} |"
      session = nil

      begin
        loggers  = []
        loggers << buffer
        loggers << $stdout
        loggers << File.expand_path(File.join(config[:logdir], "#{info[:name]}.log"), ENV['PWD']) if config[:logdir]

        session = Harvest.get(info[:name], **info.merge(log: loggers))
      rescue => e
        raise e
      end

      session
    end
    def run(args)
      config = Hash.new
      config[:env]       = []
      config[:inventory] = []
      config[:template]  = []
      config[:command]   = []
      config[:runner]    = self.method(:tty)

      parser = OptionParser.new
      parser.banner  = "#{File.basename($0)} HOST_PATTERN [Options]"
      parser.version = Harvest::VERSION

      parser.on('-i PATH', '--inventory', String, 'The PATH to the inventory file.')            { |v| config[:inventory] << v }
      parser.on('-t PATH', '--template',  String, 'The PATH to the template file or directory.'){ |v| config[:template]  << v }
      parser.on('-L PATH', '--log-dir',   String, 'The PATH to the log directory.')             { |v| config[:logdir]     = v }

      parser.on('-l',         '--list',   TrueClass, 'List the inventory.')       { |v| config[:runner] = self.method(:list) }
      #parser.on('-e COMMAND', '--exec',   String,    'Execute commands and quit.'){ |v| config[:runner] = self.method(:exec); config[:command] << v }

      config[:name]      = parser.parse!(args).first
      config[:inventory] << DEFAULT_INVENTORY if config[:inventory].empty?
      config[:template]  << DEFAULT_TEMPLATE  if config[:template].empty?

      Harvest.configure do
        source   *config[:inventory].map{ |e| File.expand_path(e, ENV['PWD']) }
        template *config[:template].map { |e| File.expand_path(e, ENV['PWD']) }
      end

      raise Harvest::Error.new("Invalid host : '#{config[:name]}'") if Harvest.list(**config.slice(:name)).empty?
      config[:runner].call(config)
    rescue => e
      $stderr.puts e, '', parser
      exit 1
    end
  end
end
