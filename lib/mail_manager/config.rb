require 'erb'
require 'yaml'

class MailManager::Config
  attr_reader :sections, :params
  
  def initialize(file = nil)
    @sections = {}
    @params = {}
    use_file!(file) if file
  end
  
  def use_file!(file)
    begin
      hash = YAML::load(ERB.new(IO.read(file)).result).with_indifferent_access
      key = old_val = new_val = nil
      @sections.merge!(hash) do |key, old_val, new_val| 
        old_val ||= Hash.new.with_indifferent_access
        new_val ||= Hash.new.with_indifferent_access
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          old_val.merge(new_val)
        else
          new_val
        end
      end
      @params.merge!(@sections['common'])
    rescue => e
      Rails.logger.error "Couldn't load config file #{file} #{e.message}"
      nil
    end    
  end
  
  def use_section!(section)
    @params.merge!(@sections[section.to_s]) if @sections.key?(section.to_s)
  end
  
  def method_missing(param)
    param = param.to_s
    if @params.key?(param)
      @params[param]
    else
      Rails.logger.warn "Invalid AppConfig Parameter " + param
      nil
    end
  end

  def self.initialize!
    standard_file = File.join(Rails.root,'config','mail_manager.yml')
    local_file = File.join(Rails.root,'config','mail_manager.local.yml')
    unless File.exists?(standard_file)
      $stderr.puts "Missing Configuration: either define ::Conf with proper values or create a config/mail_manager.yml with rake mail_manager:default_app_config"
    end
    c = ::MailManager::Config.new
    c.use_file!(standard_file)
    c.use_file!(local_file)
    c.use_section!(Rails.env)
    c
  end
  
end
