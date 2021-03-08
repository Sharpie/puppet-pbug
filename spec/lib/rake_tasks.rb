require 'puppet_litmus/rake_helper'

namespace :pbug do
  namespace :acceptance do
    modulepath = PuppetLitmus::RakeHelper::DEFAULT_CONFIG_DATA['modulepath']

    desc 'Provision test nodes for acceptance tests'
    task :provision do
      sh "bolt plan run --modulepath #{modulepath} acceptance::provision"
    end

    desc 'Set up test nodes for acceptance tests'
    task :setup do
      sh "bolt plan run --modulepath #{modulepath} --inventory inventory.yaml acceptance::setup"
    end
  end

  desc 'Run acceptance tests'
  task :acceptance => ['pbug:acceptance:provision', 'pbug:acceptance:setup']
end
