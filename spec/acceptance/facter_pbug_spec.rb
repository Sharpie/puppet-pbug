require 'spec_helper_acceptance'

describe 'the pbug fact' do
  before :all do
    # Ensure all module content is synced to the Puppet plugin cache.
    run_shell('/opt/puppetlabs/bin/puppet plugin download')
  end

  describe 'pbug.versions' do
    it 'detects the puppet version' do
      expect(host_inventory['facter'].dig('pbug', 'versions', 'puppet')).to match(/\d+\.\d+\.\d+/)
    end

    it 'detects the systemd version' do
      expect(host_inventory['facter'].dig('pbug', 'versions', 'systemd')).to match(/\d+/)
    end

    context 'when primary server components are installed' do
      ['puppetserver', 'puppetdb'].each do |component|
        it "detects the #{component} version" do
          expect(host_inventory['facter'].dig('pbug', 'versions', component)).to match(/\d+\.\d+\.\d+/)
        end
      end
    end

    context 'when PE is installed' do
      ['pe', 'pe_orchestrator', 'pe_console'].each do |component|
        it "detects the #{component} version" do
          expect(host_inventory['facter'].dig('pbug', 'versions', component)).to match(/\d+\.\d+\.\d+/)
        end
      end
    end
  end
end
