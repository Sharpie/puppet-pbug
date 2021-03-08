# Install software on provisioned test nodes
plan acceptance::setup {
  $primary_servers = get_targets('all').filter |$t| { $t.vars['role'] == primary }

  out::message('Installing PE...')

  $primary_servers.each |$server| {
    # Needed by resources configured by the PE installer
    run_command('yum install -y cronie', $server)

    run_plan('peadm::provision',
             {'master_host'           => $server,
              # FIXME: peadm bug. This parameter only accepts string values,
              #        but takes its default from `master_host`, which accepts
              #        Bolt targets or string values.
              'compiler_pool_address' => $server.name,
              'version'               => '2019.8.5',
              'download_mode'         => 'direct',
              'console_password'      => 'puppetlabs'})
  }
}
