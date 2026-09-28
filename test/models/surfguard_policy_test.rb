require "test_helper"

# Fizzy's own record of which addresses must never be reachable from a webhook
# or a push endpoint, held against the shared policy in the surfguard gem. The
# gem tests the full range matrix itself; this is the list Fizzy will not give
# up, resolved exactly the way Webhook::Delivery and Push::Subscription do.
class SurfguardPolicyTest < ActiveSupport::TestCase
  test "blocks loopback addresses" do
    stub_dns_resolution("127.0.0.1")
    assert_nil resolve("localhost")
  end

  test "blocks private 10.x.x.x addresses" do
    stub_dns_resolution("10.0.0.1")
    assert_nil resolve("internal.example.com")
  end

  test "blocks private 172.16.x.x addresses" do
    stub_dns_resolution("172.16.0.1")
    assert_nil resolve("internal.example.com")
  end

  test "blocks private 192.168.x.x addresses" do
    stub_dns_resolution("192.168.1.1")
    assert_nil resolve("internal.example.com")
  end

  test "blocks link-local addresses (AWS metadata endpoint)" do
    stub_dns_resolution("169.254.169.254")
    assert_nil resolve("metadata.example.com")
  end

  test "blocks carrier-grade NAT addresses" do
    stub_dns_resolution("100.64.0.1")
    assert_nil resolve("cgnat.example.com")
  end

  test "blocks benchmark testing addresses" do
    stub_dns_resolution("198.18.0.1")
    assert_nil resolve("benchmark.example.com")
  end

  test "blocks broadcast addresses" do
    stub_dns_resolution("0.0.0.1")
    assert_nil resolve("broadcast.example.com")
  end

  test "allows public addresses" do
    stub_dns_resolution("93.184.216.34")
    assert_equal "93.184.216.34", resolve("example.com")
  end

  test "returns first public IP when multiple addresses resolve" do
    stub_dns_resolution("10.0.0.1", "93.184.216.34", "192.168.1.1")
    assert_equal "93.184.216.34", resolve("multi.example.com")
  end

  # IPv6 address format tests (SSRF bypass prevention)

  test "blocks IPv4-mapped IPv6 addresses with private IPs" do
    stub_dns_resolution("::ffff:192.168.1.1")
    assert_nil resolve("mapped-private.example.com")
  end

  test "blocks IPv4-mapped IPv6 addresses with link-local IPs" do
    stub_dns_resolution("::ffff:169.254.169.254")
    assert_nil resolve("mapped-metadata.example.com")
  end

  test "blocks IPv4-mapped IPv6 addresses even with public IPs" do
    stub_dns_resolution("::ffff:93.184.216.34")
    assert_nil resolve("mapped-public.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses with private IPs" do
    stub_dns_resolution("::192.168.1.1")
    assert_nil resolve("compat-private.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses with link-local IPs" do
    stub_dns_resolution("::169.254.169.254")
    assert_nil resolve("compat-metadata.example.com")
  end

  test "blocks IPv4-compatible IPv6 addresses even with public IPs" do
    stub_dns_resolution("::93.184.216.34")
    assert_nil resolve("compat-public.example.com")
  end

  test "blocks NAT64 addresses embedding a private IPv4" do
    stub_dns_resolution("64:ff9b::a9fe:a9fe")  # NAT64 -> 169.254.169.254 (AWS metadata)
    assert_nil resolve("nat64-metadata.example.com")
  end

  test "blocks NAT64 addresses embedding a carrier-grade NAT IPv4" do
    stub_dns_resolution("64:ff9b::6440:1")  # NAT64 -> 100.64.0.1
    assert_nil resolve("nat64-cgnat.example.com")
  end

  test "allows NAT64 addresses embedding a public IPv4" do
    # DNS64 legitimately synthesizes these for public sites on IPv6-only hosts.
    stub_dns_resolution("64:ff9b::808:808")  # NAT64 -> 8.8.8.8
    assert_not_nil resolve("nat64-public.example.com")
  end

  # The local-use block is refused whole rather than decoded. A Pref64 inside it
  # can be any length from /32 to /96 and the position is not recoverable from
  # the address alone (RFC 6052 §2.2), so reading the low 32 bits reads the
  # wrong octets — 64:ff9b:1::808:808 only looks like 8.8.8.8 under a /96
  # reading. The block is never globally routed, so nothing legitimate is lost.
  test "blocks the local-use NAT64 block whatever it appears to embed (RFC8215)" do
    stub_dns_resolution("64:ff9b:1::a00:1")  # reads as 10.0.0.1 under a /96
    assert_nil resolve("nat64-local.example.com")

    stub_dns_resolution("64:ff9b:1::808:808")  # reads as 8.8.8.8 under a /96
    assert_nil resolve("nat64-local-public.example.com")
  end

  # The third way an IPv4 address rides inside an IPv6 one, and the only one
  # Ruby has no predicate for: ipv4_mapped?, ipv4_compat?, private?, loopback?
  # and link_local? are all false here, so it reached the metadata endpoint.
  test "blocks SIIT IPv4-translated addresses (RFC2765)" do
    stub_dns_resolution("::ffff:0:a9fe:a9fe")  # SIIT -> 169.254.169.254
    assert_nil resolve("siit-metadata.example.com")

    stub_dns_resolution("::ffff:0:7f00:1")  # SIIT -> 127.0.0.1
    assert_nil resolve("siit-loopback.example.com")
  end

  # Every address, not just the first: a host that answers with one public and
  # one internal address must not be pinned to the public one and connected on
  # whichever the OS picks.
  test "drops the internal address from a host that answers with both" do
    stub_dns_resolution("93.184.216.34", "169.254.169.254")
    assert_equal "93.184.216.34", resolve("mixed.example.com")
  end

  test "blocks 6to4 and Teredo transition addresses" do
    stub_dns_resolution("2002:a9fe:a9fe::")  # 6to4 embedding 169.254.169.254
    assert_nil resolve("sixtofour.example.com")

    stub_dns_resolution("2001::1")  # Teredo
    assert_nil resolve("teredo.example.com")
  end

  test "blocks IPv6 benchmarking addresses (RFC5180)" do
    stub_dns_resolution("2001:2::1")
    assert_nil resolve("v6-benchmark.example.com")
  end

  test "blocks IPv6 loopback, ULA, and multicast" do
    stub_dns_resolution("::1")
    assert_nil resolve("v6-loopback.example.com")

    stub_dns_resolution("fd00:ec2::254")  # AWS IMDSv6 (ULA)
    assert_nil resolve("v6-imds.example.com")

    stub_dns_resolution("ff02::1")
    assert_nil resolve("v6-multicast.example.com")
  end

  test "allows public IPv6 addresses" do
    stub_dns_resolution("2606:4700:4700::1111")
    assert_not_nil resolve("v6-public.example.com")
  end

  # The distinction Webhook::Delivery and Push::Subscription rely on: a host that
  # resolves to nothing raises Unresolvable (a lookup failure), while a host that
  # resolves only to blocked addresses returns no public IP without raising (a
  # refusal). Collapsing the two would report a DNS failure as a blocked address.
  test "raises Unresolvable on a resolution failure, distinct from a blocked address" do
    stub_dns_failure
    assert_raises(Surfguard::Unresolvable) { resolve("nxdomain.example.invalid") }

    stub_dns_resolution("10.0.0.1")
    assert_nil resolve("blocked.example.com")
  end

  private
    # Exactly what Webhook::Delivery#resolved_ip and
    # Push::Subscription#resolved_endpoint_ip do with the host they pin on.
    def resolve(host)
      Surfguard.resolve_public_ips(host).first
    end
end
