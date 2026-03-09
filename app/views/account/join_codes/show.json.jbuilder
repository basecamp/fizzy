json.(@join_code, :code, :usage_count, :usage_limit)
json.url join_url(code: @join_code.code, script_name: Current.account.slug)
json.active !!@join_code.active?
