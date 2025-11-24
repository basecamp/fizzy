namespace :saas do
  SAAS_FILE_PATH = "tmp/saas.txt"

  desc "Enable SaaS mode"
  task enable: :environment do
    file_path = Rails.root.join(SAAS_FILE_PATH)
    FileUtils.mkdir_p(File.dirname(file_path))
    FileUtils.touch(file_path)
    puts "SaaS mode enabled (#{file_path} created)"
  end

  desc "Disable SaaS mode"
  task disable: :environment do
    file_path = Rails.root.join(SAAS_FILE_PATH)
    FileUtils.rm_f(file_path)
    puts "SaaS mode disabled (#{file_path} removed)"
  end
end
