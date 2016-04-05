#
# RubyGem Wrapper for the Prosody XMPP Server
# Copyright (C) 2016  Lukas Matt <lukas@zauberstuhl.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'fileutils'

class Prosody
  GEMDIR = Gem::Specification.find_by_name(
    'diaspora-prosody-config'
  ).gem_dir.freeze

  WRAPPERCFG = "#{GEMDIR}/etc/prosody.cfg.lua".freeze
  DIASPORACFG = "#{FileUtils.pwd}/config/prosody.cfg.lua".freeze

  def initialize
    sanity_check && init_config
  end

  def start
    system("#{find_binary} --config #{WRAPPERCFG}")
  end

  private

  def find_binary
    ENV['PATH'].split(':').each do |p|
      prosodybin = "#{p}/prosody"
      return prosodybin if File.exist?(prosodybin)
    end
    abort('Prosody executable is missing please update your PATH variable')
  end

  def sanity_check
    # check on bcrypt and warn
    bcrypt_so = %x(find /usr/local/lib -name bcrypt.so) rescue ''
    warn('bcrypt is required for diaspora authentication') if bcrypt_so.empty?
    # check prosody version
    about = %x(#{find_binary}ctl about)
    version_string = begin
      about.match(/prosody\s(\d+\.\d+\.\d+)/i).captures[0]
    rescue
      abort('something went wrong with prosdoyctl')
    end
    version = Gem::Version.new(version_string)
    if version < Gem::Version.new('0.9.0')
      abort('your\'re prosody version should be >= 0.9.0')
    end
    abort('wasn\'t able to detect the Diaspora environment') unless defined?(AppConfig)
    abort('wasn\'t able to detect the Rails environment') unless defined?(Rails)
  end

  def init_config
    # update prosody cfg in diaspora config dir
    gemcfg = "#{WRAPPERCFG}.tpl"
    unless File.exist?(DIASPORACFG)
      FileUtils.cp(gemcfg, DIASPORACFG)
    end

    config = File.read(DIASPORACFG)
    config_params.each do |k, v|
      begin
        v = 'MySQL' if v.include?('mysql2')
        v = 'PostgreSQL' if v.include?('postgresql')
        v = 'SQLite3' if v.include?('sqlite3')
      rescue
        warn("Warning! #{k} is empty")
      end
      config.gsub!(/\#\{#{k}\}/, "#{v}")
    end
    File.open(WRAPPERCFG, 'w') {|f| f.write(config) }
  end

  def config_params
    db = Rails.application.config.database_configuration[Rails.env]
    hostname = AppConfig.environment.url
      .gsub(/^http(s){0,1}:\/\/|\/$/, '')
      .to_s rescue 'localhost'

    return {
      plugin_path: "#{GEMDIR}/modules",
      #log_info: AppConfig.chat.server.log.info.to_s,
      #log_error: AppConfig.chat.server.log.error.to_s,
      virtualhost_hostname: hostname,
      virtualhost_driver: db['adapter'],
      virtualhost_database: db['database'],
      virtualhost_username: db['username'],
      virtualhost_password: db['password'],
      virtualhost_host: db['host']
    }
  end
end
