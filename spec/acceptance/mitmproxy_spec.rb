require 'spec_helper_acceptance'

describe 'class pbug::mitmproxy' do
  it 'applies idempotently' do
    idempotent_apply('include pbug::mitmproxy')
  end

  describe 'mitmproxy service' do
    context 'when started' do
      describe command('systemctl start mitmproxy') do
        its(:exit_status) { should eq 0 }
      end

      describe service('mitmproxy.service') do
        it { should be_running }
      end

      describe iptables do
        it { should have_rule('--dports 4433,8081,8140,8143').with_table('nat').with_chain('OUTPUT') }
      end
    end

    context 'when stopped' do
      describe command('systemctl stop mitmproxy') do
        its(:exit_status) { should eq 0 }
      end

      describe iptables do
        it { should_not have_rule('--dports 4433,8081,8140,8143').with_table('nat').with_chain('OUTPUT') }
      end
    end
  end
end
