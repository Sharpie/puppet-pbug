require 'puppet_litmus/rake_helper'

namespace :pbug do
  namespace :acceptance do
    modulepath = PuppetLitmus::RakeHelper::DEFAULT_CONFIG_DATA['modulepath']

    desc 'Provision test nodes for acceptance tests'
    task :provision, [:provisioner, :platform] do |t, args|
      provisioner = args.provisioner || 'docker_exp'
      platform = args.platform || 'centos-7-x86_64'

      sh "bolt plan run --modulepath #{modulepath} acceptance::provision provisioner=#{provisioner} platform=#{platform}"
    end

    desc 'Set up test nodes for acceptance tests'
    task :setup do
      sh "bolt plan run --modulepath #{modulepath} --inventory inventory.yaml acceptance::setup"
    end
  end

  desc 'Run acceptance tests'
  task acceptance: ['pbug:acceptance:provision', 'pbug:acceptance:setup']
end
