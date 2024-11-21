# Start from fixtures
Tenant.find_or_create_by!(slug: "default").while_tenanted do
  Rake.application["db:fixtures:load"].invoke
end
