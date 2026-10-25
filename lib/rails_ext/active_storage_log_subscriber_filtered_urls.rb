require "active_storage/log_subscriber"

# Active Storage logs each URL it generates, and its event skips payload filtering, so a presigned
# storage URL reached the "Generated URL for file at key" line with its X-Amz-Signature: a working
# link to the file until it expires. Log the URL with its query filtered by filter_parameters, pair by
# pair, as Action Dispatch filters a redirect's location for the "Redirected to" line.
module ActiveStorageLogSubscriberFilteredUrls
  def service_url(event)
    super event.merge(payload: event[:payload].merge(url: filtered_url(event[:payload][:url])))
  end

  private
    def filtered_url(url)
      before_fragment, fragment_separator, fragment = url.to_s.partition("#")
      location, query_separator, query = before_fragment.partition("?")
      "#{location}#{query_separator}#{filtered_query(query)}#{fragment_separator}#{fragment}"
    end

    def filtered_query(query)
      query.split(/([&;])/).map do |part|
        if part.include?("=")
          name, value = part.split("=", 2)
          parameter_filter.filter(name => value).first.join("=")
        else
          part
        end
      end.join
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
end

ActiveStorage::LogSubscriber.prepend ActiveStorageLogSubscriberFilteredUrls
