class BucketFilterPresenter
  def initialize(buckets, params, cookies)
    @buckets = buckets
    @params = params
    @cookies = cookies
  end

  def filter_text
    if selected_bucket_ids.present?
      "Showing activity for #{selected_bucket_names_bold}".html_safe
    else
      "Showing everything"
    end
  end

  private
    def selected_bucket_ids
      @params[:bucket_ids].presence || @cookies[:bucket_filter]&.split(",")
    end

    def selected_bucket_names
      @buckets.where(id: selected_bucket_ids).pluck(:name).to_sentence
    end

    def selected_bucket_names_bold
      names = @buckets.where(id: selected_bucket_ids).pluck(:name)
      names.map { |name| "<strong>#{name}</strong>" }.to_sentence
    end
end
