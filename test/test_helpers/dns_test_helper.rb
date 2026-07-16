module DnsTestHelper
  WEB_PUSH_PUBLIC_TEST_IP = "142.250.185.206" # stable public IP for web push DNS stubs in tests

  private

  def stub_dns_resolution(*ips)
    dns_mock = mock("dns")
    dns_mock.stubs(:each_address).multiple_yields(*ips)
    Resolv::DNS.stubs(:open).yields(dns_mock)
  end

  def stub_web_push_dns_resolution
    stub_dns_resolution(WEB_PUSH_PUBLIC_TEST_IP)
  end
end
