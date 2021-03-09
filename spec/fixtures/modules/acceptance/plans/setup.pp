# Install software on provisioned test nodes
plan acceptance::setup {
  $primary_servers = get_targets('all').filter |$t| { $t.vars['role'] == primary }

  out::message('Installing PE...')

  $primary_servers.parallelize |$server| {
    $node_facts = run_task('facts', $server).first.value

    #debug::break()
    # Packages needed by the PE installer
    case $node_facts.get('os.family') {
      'Debian': {
        run_command('apt update && apt install -y --no-install-recommends ca-certificates cron curl gettext gnupg lsb-release', $server)
      }
      'RedHat': {
        run_command('yum install -y ca-certificates cronie curl gettext', $server)
      }
    }

    run_plan('peadm::provision',
             {'master_host'           => $server,
              # FIXME: peadm bug. This parameter only accepts string values,
              #        but takes its default from `master_host`, which accepts
              #        Bolt targets or string values.
              'compiler_pool_address' => $server.name,
              'version'               => '2019.8.5',
              'download_mode'         => 'direct',
              'console_password'      => 'puppetlabs',
              # Ensure changes to modules are picked up immediately.
              'pe_conf_data'          => {'puppet_enterprise::profile::master::code_manager_auto_configure' => false}})
  }
}
