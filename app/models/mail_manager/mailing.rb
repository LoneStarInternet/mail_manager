# encoding: utf-8
=begin rdoc
Author::    Chris Hauboldt (mailto:biz@lnstar.com)
Copyright:: 2009 Lone Star Internet Inc.

Mailing is used to send a Mailable object to an MailingList. It is 'ready' to send when its status is 'scheduled' and 'shcheduled_at' is in the past. MailingJob will poll for 'ready' Mailings and send them.

Statuses
pending - initial state - mailing is waiting to be tested and scheduled - will not send
scheduled - mailing will be sent when it is 'ready' (its status is 'scheduled' and 'shcheduled_at' is in the past)
processing - MailingJob is sending the messages for the mailing
completed - Mailing has been sent

=end

module MailManager
  class Mailing < ActiveRecord::Base
    self.table_name =  "#{MailManager.table_prefix}mailings"
    has_many :messages, :class_name => 'MailManager::Message', inverse_of: :mailing
    has_many :test_messages, :class_name => 'MailManager::TestMessage'
    has_many :bounces, :class_name => 'MailManager::Bounce'
    has_and_belongs_to_many :mailing_lists, :class_name => 'MailManager::MailingList', 
      :join_table => "#{MailManager.table_prefix}mailing_lists_#{MailManager.table_prefix}mailings"
    #FIXME why does this break? 
    belongs_to :mailable, :polymorphic => true
  
    accepts_nested_attributes_for :mailable

    include Deleteable if (column_names.include?('deleted_at') rescue false)

    attr_accessor :bounce_count

    validates_presence_of :subject
    #validates_presence_of :mailable
  
    scope :ready, lambda {{:conditions => ["(status='scheduled' AND scheduled_at < ?)",Time.now.utc]}}
    scope :by_statuses, lambda {|*statuses| {:conditions => ["status in (#{statuses.collect{|bindings,status| '?'}.join(",")})",statuses].flatten}}
  
    include StatusHistory
    override_statuses(['pending','scheduled','processing','cancelled','completed'],'pending')
    before_create :set_default_status

    attr_protected :id

    def send_one_off_message(contact)
      message = Message.new
      message.contact_id = contact.id
      message.mailing_id = self.id
      message.change_status(:ready)
      message.delay.deliver
    end
    
    def deliver
      Rails.logger.info "Starting to Process Mailing '#{subject}' ID:#{id}"
      Lock.with_lock("mail_mgr_mailing_send[#{id}]") do |lock|
        unless can_run?
          raise Exception.new("Mailing was not scheduled when job tried to run!")
        end
        unless scheduled_at <= Time.now
          Rails.logger.info "Mailing is not scheduled to run until #{scheduled_at} rescheduling job!"
          self.delay(run_at: scheduled_at).deliver
          return true
        end     
        change_status(:processing)
        initialize_messages
        messages.pending.limit(MailManager.deliveries_per_run).each do |message|
          if reload.status.to_s != 'processing'
            Rails.logger.warn "Mailing #{id} is no longer in processing status it was changed to #{status} while running"
            return false
          end
	        begin
            # should use the cached mailing parts as mailing object for message should be the same as its caller
            message.deliver(raw_parts)
	        rescue => e
	          message.result = "Error: #{e.message} - #{e.backtrace.join("\n")}"
	          message.change_status(:failed)
	        end
          Rails.logger.debug "Sleeping #{MailManager.sleep_time_between_messages} before next message"
          sleep MailManager.sleep_time_between_messages
        end
        if messages.pending.count == 0
          change_status(:completed) 
        else
          self.delay(run_at: [scheduled_at,Time.now.utc].max).deliver
        end
      end
    end
  
    def mailable
      return @mailable if @mailable
      return (@mailable=nil) if mailable_type.nil? or mailable_id.nil?
      @mailable = mailable_type.constantize.find(mailable_id)
    end

    def self.cleanse_source(source)
      require 'iconv' unless String.method_defined?(:encode)
      if String.method_defined?(:encode)
        source.encode!('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
        source.encode!('UTF-8', 'UTF-16')
      else
        ic = Iconv.new('UTF-8', 'UTF-8//IGNORE')
        source = ic.iconv(source)
      end
    end

    def self.substitute_values(source,substitutions)
      substitutions.each_pair do |substitution,value| 
        if value.blank?
          source.gsub!(/##{substitution}#([^#]*)#/,'\1') rescue source = self.cleanse_source(source).gsub(/##{substitution}#([^#]*)#/,'\1')
        else
          source.gsub!(/##{substitution}#[^#]*#/,value.to_s) rescue source = self.cleanse_source(source).gsub(/##{substitution}#[^#]*#/,value.to_s)
        end
      end
      if defined? MailManager::ContactableRegistry.respond_to?(:valid_contactable_substitutions)
        MailManager::ContactableRegistry.valid_contactable_substitutions.
          reject{|key| substitutions.keys.include?(key)}.each do |substitution|
          source.gsub!(/##{substitution}#([^#]*)#/,'\1') rescue source = self.cleanse_source(source).gsub(/##{substitution}#([^#]*)#/,'\1')
        end
      end
      source
    end
  
    def raw_parts
      @raw_parts ||= mailable.mailable_parts
    end

    def parts(substitutions={}, cached_parts=nil)
      cached_parts ||= raw_parts
      parts = []
      cached_parts.each do |type,source|
        parts << [type, Mailing.substitute_values(source.dup,substitutions)]
      end
      parts
    end
  
    def mailable=(value)
      return if value.nil?
      self[:mailable_type] = value.class.name
      self[:mailable_id] = value.id
      @mailable = value
    end
  
    def mailable_class_and_id=(value)
      return if value.nil?
      parts = value.split(/_/)
      self[:mailable_id] = parts.pop
      self[:mailable_type] = parts.join('_')
    end
  
    #def mailable_attributes=(mailable_attributes={})
    #  mailable_attributes.each_pair do |key,value|
    #  end
    #end
  
    # creates all of the Messages that will be sent for this mailing
    def initialize_messages
      emails_hash = MailManager::Message.email_address_hash_for_mailing_id(self.id)
      emails_hash.merge!(MailManager::Subscription.unsubscribed_emails_hash)
      ids = self.mailing_lists.select('id').map(&:id)
      active_subscriptions_hash = MailManager::MailingList.
        active_email_addresses_contact_ids_subscription_ids_for_mailing_list_ids(ids)
      active_subscriptions_hash.each_pair do | email, data |
        next if emails_hash[email.to_s.strip.downcase].present?
        message = MailManager::Message.create({
          :subscription_id => data[:subscription_id],
          :contact_id => data[:contact_id],
          :mailing_id => self.id
        })
      end 
    end

    def delete
      transaction do
        super
        job.destroy
      end
    end
  
    # clean up an email address for sending FIXME - maybe do a bit more
    def self.clean_email_address(email_address)
      email_address.downcase.strip
    end
  
    # sends a test message for this mailing to the given address
    def send_test_message(test_email_addresses)
      test_email_addresses.split(/,/).each do |test_email_address|
        puts "Creating test message for #{test_email_address}"
        test_message = TestMessage.new(:test_email_address => test_email_address.strip)
        test_message.mailing_id = self.id
        test_message.save
        test_message.delay.deliver
      end
    end
  
    # used in select helpers to identify this Mailing's Mailable
    def mailable_thing_and_id
      return '' if mailable.nil?
      return "#{mailable.class.name}_#{mailable.id}"
    end
  
    def mailing_list_ids=(mailing_list_ids)
      mailing_list_ids.delete('')
      self.mailing_lists = mailing_list_ids.collect{|mailing_list_id| MailingList.find_by_id(mailing_list_id)}
    end
  
    def can_edit?
      ['pending','scheduled'].include?(status.to_s)
    end
  
    def can_cancel?
       ['pending','scheduled','processing'].include?(status.to_s)
    end

    def can_run?
       # processing is allowed for failed job reset and is OK since we lock around whole job
       ['scheduled','processing'].include?(status.to_s)
    end
  
    def can_schedule?
      ['pending'].include?(status.to_s) && scheduled_at.present?
    end
  
    def schedule
      raise "Unable to schedule" unless can_schedule?
      change_status('scheduled')
      delay(run_at: scheduled_at).deliver
    end

    def scheduled?
      status.to_s.eql?('scheduled')
    end

    def job
      mailing_jobs.first
    end
  
    def mailing_jobs
      Delayed::Job.where("handler like ?","%MailManager::Mailing% id: #{self.id}\n%")
    end

    def cancel
      raise "Unable to cancel" unless can_cancel?
      change_status('pending')
      mailing_jobs.delete_all
    end

    def pending?
      status.to_s.eql?('pending')
    end
  
  end
end
