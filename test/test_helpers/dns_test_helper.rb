module DnsTestHelper
  WEB_PUSH_PUBLIC_TEST_IP = "142.250.185.206" # stable public IP for web push DNS stubs in tests

  private

  # Surfguard resolves through Resolv.getaddresses, which honours /etc/hosts and
  # search domains and returns every address a host answers with.
  def stub_dns_resolution(*ips)
    Resolv.stubs(:getaddresses).returns(ips.map(&:to_s))
  end

  # A host that resolves to nothing: the resolver errors (timeout/NXDOMAIN),
  # which Surfguard catches and reports as Unresolvable, distinct from a host
  # that resolves only to blocked addresses.
  def stub_dns_failure(error = Resolv::ResolvError)
    Resolv.stubs(:getaddresses).raises(error)
  end

  def stub_web_push_dns_resolution
    stub_dns_resolution(WEB_PUSH_PUBLIC_TEST_IP)
  end
end
