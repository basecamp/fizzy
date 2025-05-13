class Command::VisitUrl < Command
  store_accessor :data, :url

  def title
    "Visit #{url}"
  end

  def execute
    redirect_to url
  end
end
