class Heroku::Analytics
  extend Heroku::Helpers

  def self.record(command)
    return if skip_analytics
    commands = json_decode(File.read(path)) || [] rescue []
    commands << {command: command, timestamp: Time.now.to_i, version: Heroku::VERSION, platform: RUBY_PLATFORM, language: "ruby/#{RUBY_VERSION}"}
    File.open(path, 'w') { |f| f.write(json_encode(commands)) }
  rescue
  end

  def self.submit
    return if skip_analytics
    commands = json_decode(File.read(path))
    return if commands.count < 10 # only submit if we have 10 entries to send
    begin
      fork do
        submit_analytics(user, commands, path)
      end
    rescue NotImplementedError
      # cannot fork on windows
      submit_analytics(user, commands, path)
    end
  rescue
  end

  private

  def self.submit_analytics(user, commands, path)
    payload = {
      user:     user,
      commands: commands,
    }
    Excon.post('https://cli-analytics.heroku.com/record', body: JSON.dump(payload))
    File.truncate(path, 0)
  end

  def self.skip_analytics
    return true if ['1', 'true'].include?(ENV['HEROKU_SKIP_ANALYTICS'])
    return true if ENV['CODESHIP'] == 'true'

    if Heroku::Config[:skip_analytics] == nil
      stderr_puts "Heroku CLI submits usage information back to Heroku. If you would like to disable this, set `skip_analytics: true` in #{Heroku::Config.path}"
      Heroku::Config[:skip_analytics] = false
      Heroku::Config.save!
    end

    Heroku::Config[:skip_analytics]
  end

  def self.path
    File.join(Heroku::Helpers.home_directory, ".heroku", "analytics.json")
  end

  def self.user
    credentials = Heroku::Auth.read_credentials
    credentials[0] if credentials
  end
end
