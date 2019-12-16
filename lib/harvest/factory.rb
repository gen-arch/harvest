# frozen_string_literal: true

require 'singleton'
require 'uri'

module Harvest
  class Factory
    include Singleton
    attr_accessor :inventory
    attr_accessor :templates

    def initialize
      @inventory = {}
      @templates = {}
    end

    def set_source(name, **args)
      args[:name]      = name
      @inventory[name] = args
    end

    def set_template(name, klass)
      @templates[name] = klass
    end

    def query(q)
      list = inventory.map { |_k, v| v }
      return list if q.empty?

      list.select do |h|
        q.any? do |k, v|
          case v
          when Regexp
            h[k] =~ v
          else
            h[k] == v
          end
        end
      end
    end

    def yaml(file)
      raise Error, 'not cofnig file' unless File.exist?(file)

      srcs = YAML.load_file(file)
      srcs.each do |src|
        src        = src.inject({}) { |h, (k, v)| h = h.merge(k.to_sym => v) }
        name       = src.delete(:host)
        set_source(name, **src)
      end
    end

    def dsl(str)
      instance_eval(str)
    end

    def method_missing(method, *args, **options)
      super unless args.size == 2

      name = args.shift
      uri  = URI.parse(args.shift)

      options[:type]       = method
      options[:uri]        = uri
      options[:name]       = name
      options[:host_name]  = uri.host
      options[:user]       = uri.user
      options[:password]   = uri.password

      set_source(name, **options)
    end
  end
end
