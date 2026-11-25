# Rails filters the Parameters hash by each parameter's name as it parses it, but the URLs it logs
# (request.filtered_path for the "Started" line and the controller instrumentation, response.filtered_location
# for redirects) by each pair's name as sent, and sinks that record a URL themselves see it raw: the
# structured request log's url.full, url.query and referrer, Sentry's Referer header, and OpenTelemetry's
# http.target and http.url. This filters a URL's query pair by pair with the same filter_parameters, so a
# ?code= or ?sid= reads [FILTERED] wherever the URL lands.
#
# A pair is filtered when Rails would filter the parameter it parses into, using Rails' own parser: so
# ?s%69d= (params[:sid]), sid[x]= and a[]sid= are filtered, and [sid]= or s+id=, which Rails reads as
# other names, aren't. Pairs split on & as Rails splits them; a pair is also filtered if splitting it on ;
# as some other reader might would expose a filtered name. The URL keeps every name, separator, fragment
# and unfiltered value as sent.
module FilteredQuery
  extend self

  PAIR_SEPARATOR = /(& *)/ # ActionDispatch::QueryParser::DEFAULT_SEP, kept in the output
  PROBE = "x"

  def filter_url(url, parameter_filter = default_parameter_filter)
    rest, hash, fragment = url.to_s.partition("#")
    base, question, query = rest.partition("?")
    question.empty? ? url : "#{base}?#{filter_query(query, parameter_filter)}#{hash}#{fragment}"
  end

  def filter_query(query, parameter_filter = default_parameter_filter)
    query.to_s.split(PAIR_SEPARATOR).map { |pair| filter_pair(pair, parameter_filter) }.join
  end

  private
    def filter_pair(pair, parameter_filter)
      if pair.include?("=") && filtered?(pair, parameter_filter)
        "#{pair.split("=", 2).first}=#{ActiveSupport::ParameterFilter::FILTERED}"
      else
        pair
      end
    end

    def filtered?(pair, parameter_filter)
      [ pair, *pair.split(/; */) ].map { |part| part.split("=", 2).first.to_s }.uniq.any? { |name| filtered_name?(name, parameter_filter) }
    end

    # Parsed with a stand-in value, so a value Rails can't decode doesn't hide the name. A name Rails can't
    # parse at all (bad %-encoding, nested too deep) is filtered: Rails refuses the request, so the value
    # was never a parameter, and there's no telling what another reader would make of it.
    def filtered_name?(name, parameter_filter)
      params = ActionDispatch::ParamBuilder.from_query_string("#{name}=#{PROBE}")
      parameter_filter.filter(params) != params
    rescue ActionDispatch::ParamError
      true
    end

    def default_parameter_filter
      ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
end
