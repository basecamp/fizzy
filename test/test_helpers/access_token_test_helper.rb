module AccessTokenTestHelper
  # Fixture tokens are stored only as digests, as every token is. These are
  # the raw values test/fixtures/identity/access_tokens.yml digests.
  RAW_FIXTURE_TOKENS = {
    jasons_api_token: "018cf1425682700098f24f0799e3fe20",
    davids_api_token: "x18cf1425682700098f24f0799e3fe20"
  }

  # Each fixture token carries its raw value in memory, as a token does on the
  # record that issued it, so a test can present it as raw_token.
  def identity_access_tokens(*)
    super.tap do |found|
      Array(found).each { |access_token| access_token.raw_token ||= raw_fixture_tokens_by_digest[access_token.token_digest] }
    end
  end

  private
    def raw_fixture_tokens_by_digest
      RAW_FIXTURE_TOKENS.values.index_by { |raw| TokenDigester.digest(raw) }
    end
end
