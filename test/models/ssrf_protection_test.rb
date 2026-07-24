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

  # IPv6 address format tests (SSRF bypass prevention)

  test "blocks IPv4-mapped IPv6 addresses with private IPs" do
    stub_dns_resolution("::ffff:192.168.1.1")
    assert_nil SsrfProtection.resolve_public_ip("mapped-private.example.com")
  end

  test "blocks IPv4-mapped IPv6 addresses with link-local IPs" do
    stub_dns_resolution("::ffff:169.254.169.254")
    assert_nil SsrfProtection.resolve_public_ip("mapped-metadata.example.com")
  end

  test "blocks IPv4-mapped IPv6 addresses even with public IPs" do
    stub_dns_resolution("::ffff:93.184.216.34")
    assert_nil SsrfProtection.resolve_public_ip("mapped-public.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses with private IPs" do
    stub_dns_resolution("::192.168.1.1")
    assert_nil SsrfProtection.resolve_public_ip("compat-private.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses with link-local IPs" do
    stub_dns_resolution("::169.254.169.254")
    assert_nil SsrfProtection.resolve_public_ip("compat-metadata.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses even with public IPs" do
    stub_dns_resolution("::93.184.216.34")
    assert_nil SsrfProtection.resolve_public_ip("compat-public.example.com")
  end

  test "blocks NAT64 addresses embedding a private IPv4" do
    stub_dns_resolution("64:ff9b::a9fe:a9fe")  # NAT64 -> 169.254.169.254 (AWS metadata)
    assert_nil SsrfProtection.resolve_public_ip("nat64-metadata.example.com")
  end

  test "blocks NAT64 addresses embedding a carrier-grade NAT IPv4" do
    stub_dns_resolution("64:ff9b::6440:1")  # NAT64 -> 100.64.0.1
    assert_nil SsrfProtection.resolve_public_ip("nat64-cgnat.example.com")
  end

  test "allows NAT64 addresses embedding a public IPv4" do
    # DNS64 legitimately synthesizes these for public sites on IPv6-only hosts.
    stub_dns_resolution("64:ff9b::808:808")  # NAT64 -> 8.8.8.8
    assert_not_nil SsrfProtection.resolve_public_ip("nat64-public.example.com")
  end

  test "blocks local-use NAT64 addresses embedding a private IPv4 (RFC8215)" do
    stub_dns_resolution("64:ff9b:1::a00:1")  # local-use NAT64 -> 10.0.0.1
    assert_nil SsrfProtection.resolve_public_ip("nat64-local.example.com")
  end

  test "allows local-use NAT64 addresses embedding a public IPv4 (RFC8215)" do
    stub_dns_resolution("64:ff9b:1::808:808")  # local-use NAT64 -> 8.8.8.8
    assert_not_nil SsrfProtection.resolve_public_ip("nat64-local-public.example.com")
  end

  test "blocks 6to4 and Teredo transition addresses" do
    stub_dns_resolution("2002:a9fe:a9fe::")  # 6to4 embedding 169.254.169.254
    assert_nil SsrfProtection.resolve_public_ip("sixtofour.example.com")

    stub_dns_resolution("2001::1")  # Teredo
    assert_nil SsrfProtection.resolve_public_ip("teredo.example.com")
  end

  test "blocks IPv6 benchmarking addresses (RFC5180)" do
    stub_dns_resolution("2001:2::1")
    assert_nil SsrfProtection.resolve_public_ip("v6-benchmark.example.com")
  end

  test "blocks IPv6 loopback, ULA, and multicast" do
    stub_dns_resolution("::1")
    assert_nil SsrfProtection.resolve_public_ip("v6-loopback.example.com")

    stub_dns_resolution("fd00:ec2::254")  # AWS IMDSv6 (ULA)
    assert_nil SsrfProtection.resolve_public_ip("v6-imds.example.com")

    stub_dns_resolution("ff02::1")
    assert_nil SsrfProtection.resolve_public_ip("v6-multicast.example.com")
  end

  test "allows public IPv6 addresses" do
    stub_dns_resolution("2606:4700:4700::1111")
    assert_not_nil SsrfProtection.resolve_public_ip("v6-public.example.com")
  end
end
