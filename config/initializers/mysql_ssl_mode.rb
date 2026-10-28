# mysql2 built against MariaDB Connector/C, as in the Docker image, ignores verify_ca and
# connects without checking the server certificate.
if ENV["MYSQL_SSL_MODE"].to_s.casecmp?("verify_ca")
  raise "MYSQL_SSL_MODE=verify_ca is not supported. Use verify_identity, which checks the server certificate and its host name."
end
