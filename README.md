Mail Manager
============

The gem provides an interface to manage mailing lists, scheduling of email mailings, subscribe/unsubscribe from lists by contacts, and view reports of bounces and possible track views of emails. Currently unsubscribes a contact from all email lists. We might add a subscription management interface later to let a user unsubscribe selectively from a selection of mailing lists. An interface is provided to register mailable objects such as a newsletter from our newsletter gem. You can see how to do this in the Mailable Registry: app/models/mail_manager/mailable_registry.rb

Also available as a stand alone application called [iReach](https://github.com/LoneStarInternet/iReach/releases) including the newsletter manager (newsletter template and elements manager, simple wysiwyg interface to create newsletters, and newsletter archive) and user access management. There is also the i_reach gem that ties mail_manager and newsletter together into one gem.

Online Documentation
--------------------
* [Homepage](http://ireachnews.com/mail_manager_documentation.html)
* [Changelog](http://www.ireachnews.com/index.html#changelog)

Requirements
------------
* Rails 3.2.x (currently tested with rails 3.2.25)
* Ruby 2.1.5 (currently tested with 2.1.5, we have tested against 1.9.3, but ruby devs no longer support it)
* [Bundler](http://bundler.io)
* [Delayed::Job](https://github.com/collectiveidea/delayed_job/) - (currently the only queue job runnerwe support)

Optional Dependencies
---------------------
* [RVM](http://rvm.io) - How we control our ruby environment (mainly concerns development)
* currently we use github/git for our repository

Installation
------------
Using bundler, edit your Gemfile.. add a one of the following lines:
```ruby
    gem 'mail_manager', '~>3' # this points to the latest rails stable 3.2.x version
    # OR
    gem 'mail_manager', git: 'https://github.com/LoneStarInternet/mail_manager.git', branch: 'rails3.2.x' # for the bleeding edge rails 3.2.x version
```
Then run bundle install:
```
    bundle install
```
Generate and configure the mail manager settings file at config/mail_manager.yml: (replace table prefix with something... or nothing if you don't want to scope it)
```
    rake mail_manager:default_app_config[table_prefix]
```
Generate migrations:
```
    rake mail_manager:import_migrations
```
Generate delayed_jobs (this is the only job runner we support right now):
```
    rails g delayed_job:active_record
```

**NOTE:** you need to create an email account that will receive bounces from your mailings (and allow POP)... configure in the following file:

Add your routes to config/routes.rb (you can say where with at: '/path')
```ruby
    mount MailManager::Engine, at: '/admin/mail_manager'
```

config/mail_manager.yml
-----------------------
This is where amost all of your configuration options are for this gem... current generator will add documentation to it (preserving your current settings) .. we'll probably want to upgrade to something like: [AppConfig](https://github.com/Oshuma/app_config) gem


You can generate this file like above (where table_prefix is for prefixing table names):
```
    rake mail_manager:default_app_config[table_prefix]
```
* This generator adds settings documentation to the yml file
* You can override values with a config/mail_manager.local.yml
* For a full description [See the documentation](http://ireachnews.com/mail_manager_documentation.html)

Securing your App
-----------------
We implemented [CanCan](https://github.com/CanCanCommunity/cancancan). If you'd like to secure your actions to certain users and don't currently have any authorization in your app, you can follow the following steps if you want an easy config.. or you could make it more finely grained.. currently its all or nothing.

Development
-----------
If you wish to contribute, you should follow these instructions to get up and running:
[See the wiki](https://github.com/LoneStarInternet/mail_manager/wiki/Contributing)

Please write tests for any new functionality and run the test suite to make sure all tests are passing.

Thanks in advance for your contributions to the project!
