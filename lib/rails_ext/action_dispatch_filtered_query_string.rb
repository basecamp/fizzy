require "filtered_query"

# Rails filters the query in request.filtered_path for the "Started" line, and response.filtered_location
# for "Redirected to", by each pair's name as sent, and splits pairs on ; as well as &, which its own
# parser doesn't. So ?q=alpha;beta, which Rails reads as one q, logged "q=[FILTERED];beta". Filter both
# by the parameter Rails parses each pair into, as HEY does (FilteredQuery).
module ActionDispatch::FilteredQueryString
  private
    def filtered_query_string
      FilteredQuery.filter_query(query_string, parameter_filter)
    end
end

module ActionDispatch::FilteredLocationQuery
  private
    def parameter_filtered_location
      FilteredQuery.filter_url(location, request.parameter_filter)
    end
end

ActiveSupport.on_load :action_dispatch_request do
  prepend ActionDispatch::FilteredQueryString
end

ActiveSupport.on_load :action_dispatch_response do
  prepend ActionDispatch::FilteredLocationQuery
end
