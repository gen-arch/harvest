# -*- encoding: utf-8 -*-
# stub: net-ssh-telnet 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "net-ssh-telnet".freeze
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sean Dilda".freeze]
  s.date = "2017-10-09"
  s.description = "A ruby module to provide a simple send/expect interface over SSH with an API almost identical to Net::Telnet. Ideally it should be a drop in replacement. Please see Net::Telnet for main documentation (included with ruby stdlib).".freeze
  s.email = ["sean@duke.edu".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "History.md".freeze]
  s.files = ["History.md".freeze, "README.md".freeze]
  s.homepage = "https://github.com/duke-automation/net-ssh-telnet".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Provides Net::Telnet API for SSH connections".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<net-ssh>.freeze, [">= 2.0.1"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    else
      s.add_dependency(%q<net-ssh>.freeze, [">= 2.0.1"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<net-ssh>.freeze, [">= 2.0.1"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
  end
end
