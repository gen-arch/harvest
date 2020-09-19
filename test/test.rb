require 'harvest'

Harvest.configure do
  source   "centos7 'host1', 'ssh://vagrant:vagrant@localhost', port: 2222"
  source   "centos7 'host2', 'ssh://vagrant:vagrant@localhost', port: 2200"

  template(type: :centos7) do
    bind(:iplist) do
      cmd('ifconfig')
    end
  end
end


s = Harvest.get("host1", log: "log/#{host}.log")

puts s.cmd('hostname')
s.close

