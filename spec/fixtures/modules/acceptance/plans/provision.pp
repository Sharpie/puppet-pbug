# Provision containers for acceptance tests
plan acceptance::provision {
  out::message ('Provisioning a CentOS 7 container...')

  # FIXME: Using docker_exp because puppetlabs-peadm can't handle Bolt
  #        nodes that are defined just by their URI. There is a peadm
  #        or provision bug here.
  run_task('provision::docker_exp',
           'local://localhost',
           action    => 'provision',
           platform  => 'litmusimage/centos:7',
           # NOTE: Without LC_ALL, the locale is set to POSIX which causes
           #       installation failures as commands like `systemctl status`
           #       produce UTF-8 characters, but Ruby is running with the
           #       US-ASCII locale.
           # NOTE: Need to mount the cgroup volume, otherwise SystemD fails
           #       to properly adopt Postgres PIDs:
           #         https://github.com/moby/moby/issues/38749
           vars      => @(EOS),
             ---
             docker_run_opts:
               - '--env LC_ALL=en_US.UTF-8'
               - '--volume /sys/fs/cgroup:/sys/fs/cgroup:ro'
             role: primary
             | EOS
           inventory => './',)
}
