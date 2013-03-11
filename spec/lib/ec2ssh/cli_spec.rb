require 'spec_helper'
require 'ec2ssh/cli'
require 'ec2ssh/dotfile'

describe Ec2ssh::CLI do
  before(:all) do
    Ec2ssh::Hosts.tap do |cls|
      cls.class_eval do
        def all
          [
            {:host => 'db-01', :dns_name => 'ec2-1-1-1-1.ap-northeast-1.ec2.amazonaws.com'},
            {:host => 'db-02', :dns_name => 'ec2-1-1-1-2.ap-northeast-1.ec2.amazonaws.com'},
          ]
        end
      end
    end
  end
  let(:cli) { described_class }
  let(:ssh_config_path) do
    path = tmp_dir.join('ssh_config')
    path.open('w') {|f| f.write <<-END }
Host foo.bar.com
  HostName 1.2.3.4
    END
    path
  end
  let(:ssh_config_string) { ssh_config_path.read }
  let(:dotfile_path) do
    tmp_dir.join('dot.ec2ssh')
  end

  around do |example|
    tz = ENV['TZ']
    ENV['TZ'] = 'UTC'
    Timecop.freeze(Time.local(2013,1,1,0,0,0)) { example.call }
    ENV['TZ'] = tz
  end

  subject { ssh_config_string }

  describe '#init' do
    before do
      silence(:stdout) { cli.start %W[init --path #{ssh_config_path} --dotfile #{dotfile_path}] }
    end

    it { should eq(<<-END) }
Host foo.bar.com
  HostName 1.2.3.4
### EC2SSH BEGIN ###
# Generated by ec2ssh http://github.com/mirakui/ec2ssh
# DO NOT edit this block!
# Updated 2013-01-01T00:00:00+00:00

### EC2SSH END ###
END
  end

  describe '#update' do
    before do
      silence(:stdout) do
        cli.start %W[init --path #{ssh_config_path} --dotfile #{dotfile_path}]
        cli.start %W[update --path #{ssh_config_path} --dotfile #{dotfile_path}]
      end
    end

    it { should eq(<<-END) }
Host foo.bar.com
  HostName 1.2.3.4
### EC2SSH BEGIN ###
# Generated by ec2ssh http://github.com/mirakui/ec2ssh
# DO NOT edit this block!
# Updated 2013-01-01T00:00:00+00:00
Host db-01
  HostName ec2-1-1-1-1.ap-northeast-1.ec2.amazonaws.com
Host db-02
  HostName ec2-1-1-1-2.ap-northeast-1.ec2.amazonaws.com

### EC2SSH END ###
END
  end

  describe '#update with aws-keys option' do
    before do
      silence(:stdout) do
        cli.start %W[init --path #{ssh_config_path} --dotfile #{dotfile_path}]
      end
      dotfile = Ec2ssh::Dotfile.load(dotfile_path)
      dotfile['aws_keys']['key1'] = {
        'access_key_id' => 'ACCESS_KEY_ID',
        'secret_access_key' => 'SECRET_ACCESS_KEY'
      }
      @output = capture(:stdout) do
        cli.start %W[update --path #{ssh_config_path} --dotfile #{dotfile_path} --aws-key #{keyname}]
      end
    end

    subject { @output }

    context do
      let(:keyname) { 'default' }
      it { should =~ /Updated 2 hosts/ }
    end

    context do
      let(:keyname) { 'key1' }
      it { should =~ /Updated 2 hosts/ }
    end

    context do
      let(:keyname) { 'key2' }
      it { should_not =~ /^Updated 2 hosts/ }
    end
  end

  describe '#remove' do
    before do
      silence(:stdout) do
        cli.start %W[init --path #{ssh_config_path} --dotfile #{dotfile_path}]
        cli.start %W[update --path #{ssh_config_path} --dotfile #{dotfile_path}]
        cli.start %W[remove --path #{ssh_config_path} --dotfile #{dotfile_path}]
      end
    end

    it { should eq(<<-END) }
Host foo.bar.com
  HostName 1.2.3.4
END
  end
end