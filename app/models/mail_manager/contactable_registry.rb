module MailManager
  class ContactableRegistry
    
    @@contactable_things = {}
    def self.register_contactable(classname, methods={})
      @@contactable_things.merge!(classname => methods)
      Rails.logger.warn "Registered Contactable: #{classname}"
      Rails.logger.debug "Current Contactables: #{@@contactable_things.inspect}"
    end
    
    def self.registered_methods(classname=nil)
      return @@contactable_things[classname.to_s].keys unless classname.nil?
      all_methods = {}
      @@contactable_things.values.each do |methods|
        all_methods.merge!(methods)
      end
      all_methods.keys.reject{|key| key.to_s.eql?('edit_route')}
    end
    
    def self.valid_contactable_substitutions(classname=nil)
      registered_methods(classname).collect{|key| key.to_s.upcase}
    end
  
    def self.contactable_method(classname,method)
      @@contactable_things[classname][method] || method
    end

    def self.edit_route_for(classname)
      return @@contactable_things[classname][:edit_route] if @@contactable_things[classname][:edit_route].present?
      "edit_#{classname.underscore}_path"
    end
    
    module Contactable

      #FIXME: this is NOT secure!!!!
      def update_contactable_data
        set_contactable_data && self.contact.save
      end
      def set_contactable_data
        unless self.is_a?(MailManager::Contact)
          if self.contact.present?
            self.contact.update_attributes(
              :first_name => contactable_value(:first_name).to_s,
              :last_name => contactable_value(:last_name).to_s,
              :email_address => contactable_value(:email_address).to_s)
          else
            self.contact = Contact.new(
              :contactable => self,
              :first_name => contactable_value(:first_name).to_s,
              :last_name => contactable_value(:last_name).to_s,
              :email_address => contactable_value(:email_address).to_s
            )
          end
        end
        self.contact.present? and self.contact.errors.empty?
      end
      
      def initialize_subscriptions
        if self.contact.nil?
          self.contact = MailManager::Contact.new(
            :first_name => contactable_value(:first_name).to_s,
            :last_name => contactable_value(:last_name).to_s,
            :email_address => contactable_value(:email_address).to_s)
        end
        self.contact.initialize_subscriptions
      end

      def subscription_status_for(mailing_list)
        subscriptions.detect{|subscription| subscription.mailing_list_id.eql?(mailing_list.id)}.status
      end

      def update_subscription_data
        Rails.logger.debug "Updating Subscriptions: #{@subscriptions_attributes.inspect} - #{subscriptions.inspect}"
        subscriptions.each do |subscription|
          Rails.logger.debug "Updating Subscription attributes for: #{subscription.inspect}"
          unless @subscriptions_attributes.nil?
            subscription_attributes = get_subscription_atttributes_for_subscription(subscription)
            if subscription.new_record? and subscription_attributes[:status] != 'active'
              Rails.logger.debug "Skipping new subscription save, since we're not subscribing"
              subscription.change_status(subscription_attributes[:status],false)
              #mucking with the array messes up the each!
              #subscriptions.delete_if{|my_subscription| my_subscription.mailing_list_id == subscription.mailing_list_id}
            elsif subscription_attributes[:status].present?
              Rails.logger.debug "Changing from #{subscription.status} to #{subscription_attributes[:status]}"
              subscription.change_status(subscription_attributes[:status])
            end
          end
        end
        true
      end
      
      def get_subscription_atttributes_for_subscription(subscription)
        return {} if @subscriptions_attributes.nil?
        subscriptions_attributes.values.detect{|subscription_attributes| 
          subscription_attributes[:mailing_list_id].to_i == subscription.mailing_list_id.to_i} || {}
      end

      def subscribe(mailing_list, status='active')
        set_contactable_data
        MailManager::Subscription.subscribe(contact,mailing_list, status)
      end

      def unsubscribe(mailing_list)
        set_contactable_data && MailManager::Subscription.unsubscribe(contact,mailing_list)
      end

      def change_subscription_status(mailing_list,status)
        set_contactable_data && MailManager::Subscription.change_subscription_status(contact,mailing_list,status)
      end

      def contactable_value(method)
        begin
          send(contactable_method(method.to_sym))
        rescue => e
          nil
        end
      end

      def contactable_method(method)
        begin
          MailManager::ContactableRegistry.contactable_method(self.class.name,method.to_sym)
        rescue => e
          method
        end
      end
      
      def reload
        @subscriptions = nil
      end
      
      def subscriptions
        return @subscriptions unless @subscriptions.nil?
        set_contactable_data unless self.contact.present?
        @subscriptions = contact.initialize_subscriptions
      end
      
      def active_subscriptions
        subscriptions.select{|subscription| subscription.active?}
      end

      def destroy
        self.transaction do
          super
          contact.try(:delete)
        end
      end
      
      def save(*args)
        success = true
        if args[0] != false
          begin 
            transaction do 
              success = success && super
              if self.contactable_value(:email_address).present?
                Rails.logger.debug "User save super success? #{success.inspect}"
                success = update_subscription_data && success
                Rails.logger.debug "User save subscription data success? #{success.inspect}"
                success = update_contactable_data unless (!success or self.is_a?(MailManager::Contact))
                Rails.logger.debug "User save contactable data success? #{success.inspect}"
              end
              raise "Failed to update contactable and/or #{self.class.name} data." unless success
            end
          rescue => e
            Rails.logger.debug "User save failed! #{e.message} #{e.backtrace.join("\n  ")}"
          end
          Rails.logger.debug "User save successful? #{success}"
        else
          success = super
        end
        success
      end

      module Associations
        def self.included(model)
          model.class_eval do
            has_one :contact, :as => :contactable, :class_name => 'MailManager::Contact'
            #overloading with some extra stuff is better than this
            #has_many :subscriptions, :through => :contact, :class_name => 'MailManager::Subscription'
          end
        end
      end

      module AttrAccessors
        def self.included(model)
          model.class_eval do
            after_create :save
            attr_accessor :subscriptions_attributes
            attr_accessible :subscriptions_attributes
          end
        end
      end
      
      def self.included(model)
        model.send(:include, Associations)
        model.send(:include, AttrAccessors)
      end
    end
  end
end
