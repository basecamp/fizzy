module DnsTestHelper
  private

  def stub_dns_resolution(*ips)
    dns_mock = mock("dns")
    dns_mock.stubs(:each_address).multiple_yields(*ips)
    Resolv::DNS.stubs(:open).yields(dns_mock)
  end
end
