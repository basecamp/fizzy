# This is meant to provide a sequential ID for +external_account_id+ when creating
# accounts without one. The SaaS version of the app uses that column, but most apps
# can just go with the default handling here.
class ExternalAccount < ApplicationRecord
end
