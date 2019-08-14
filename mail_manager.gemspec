# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mail_manager/version'

Gem::Specification.new do |gem|
  gem.name          = "mail_manager"
  gem.version       = MailManager::VERSION
  gem.authors       = ["Lone Star Internet", "Christopher Hauboldt"]
  gem.email         = ["biz@lone-star.net", 'chauboldt@lone-star.net']
  gem.licenses      = ["MIT"]
  gem.description   = %q{Manages the delivery of mailable items. Handles contacts, mailing lists, bounces, unsubscribe, opt-in, etc. Also available with a newsletter manager (including newsletter designs and elements management, wysiwyg newsletter editor, and newsletter archive) as well as user access control as part of the iReach gem.}
  gem.summary       = %q{Mailing list management tool}
  gem.homepage      = "http://ireachnews.com"

  gem.add_dependency "rails", "~>3.2"
  gem.add_dependency 'rack-protection', '=2.0.1'
  gem.add_dependency 'jquery-rails', "~>3.1"
  gem.add_dependency 'jquery-ui-rails', "~>5.0"
  gem.add_dependency 'jquery-ui-themes', "~>0.0"
  gem.add_dependency "daemons", "~>1.1"
  gem.add_dependency "with_lock", "~>0.1"
  gem.add_dependency "mini_magick", "=4.9.4"
  gem.add_dependency "will_paginate", "~>3.0"
  gem.add_dependency 'unix_utils', "~>0.0"
  gem.add_dependency "delayed_job", '~>4'
  gem.add_dependency 'delayed_job_active_record', '~>4'
  gem.add_dependency "dynamic_form", "~>1.1"
  gem.add_dependency 'cancancan', "~>1.9"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
