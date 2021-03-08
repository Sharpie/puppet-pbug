function acceptance::platform_to_litmusimage(String $platform) >> String {
  # NOTE: This may make more sense as a Hiera lookup as that would make it
  #       easy to extend/override with custom images.
  case $platform {
    'centos-7-x86_64': { 'litmusimage/centos:7' }
    'centos-8-x86_64': { 'litmusimage/centos:8' }
    'ubuntu-1604-x86_64': { 'litmusimage/ubuntu:16.04' }
    # FIXME: PE installation currently fails because `systemctl enable pe-postgresql`
    #        fails for inscrutable reasons.
    'ubuntu-1804-x86_64': { 'litmusimage/ubuntu:18.04' }
    'ubuntu-2004-x86_64': { 'litmusimage/ubuntu:20.04' }
    default: { fail("No docker image defined for the following platform: ${platform}") }
  }
}
