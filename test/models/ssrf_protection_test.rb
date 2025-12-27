require "test_helper"

class SsrfProtectionTest < ActiveSupport::TestCase
  test "blocks loopback addresses" do
    stub_dns_resolution("127.0.0.1")
    assert_nil SsrfProtection.resolve_public_ip("localhost")
  end

  test "blocks private 10.x.x.x addresses" do
    stub_dns_resolution("10.0.0.1")
    assert_nil SsrfProtection.resolve_public_ip("internal.example.com")
  end

  test "blocks private 172.16.x.x addresses" do
    stub_dns_resolution("172.16.0.1")
    assert_nil SsrfProtection.resolve_public_ip("internal.example.com")
  end

  test "blocks private 192.168.x.x addresses" do
    stub_dns_resolution("192.168.1.1")
    assert_nil SsrfProtection.resolve_public_ip("internal.example.com")
  end

  test "blocks link-local addresses (AWS metadata endpoint)" do
    stub_dns_resolution("169.254.169.254")
    assert_nil SsrfProtection.resolve_public_ip("metadata.example.com")
  end

  test "blocks carrier-grade NAT addresses" do
    stub_dns_resolution("100.64.0.1")
    assert_nil SsrfProtection.resolve_public_ip("cgnat.example.com")
  end

  test "blocks benchmark testing addresses" do
    stub_dns_resolution("198.18.0.1")
    assert_nil SsrfProtection.resolve_public_ip("benchmark.example.com")
  end

  test "blocks broadcast addresses" do
    stub_dns_resolution("0.0.0.1")
    assert_nil SsrfProtection.resolve_public_ip("broadcast.example.com")
  end

  test "allows public addresses" do
    stub_dns_resolution("93.184.216.34")
    assert_equal "93.184.216.34", SsrfProtection.resolve_public_ip("example.com")
  end

  test "returns first public IP when multiple addresses resolve" do
    stub_dns_resolution("10.0.0.1", "93.184.216.34", "192.168.1.1")
    assert_equal "93.184.216.34", SsrfProtection.resolve_public_ip("multi.example.com")
  end

  private
    def stub_dns_resolution(*ips)
      dns_mock = mock("dns")
      dns_mock.stubs(:each_address).multiple_yields(*ips)
      Resolv::DNS.stubs(:open).yields(dns_mock)
    end
end
