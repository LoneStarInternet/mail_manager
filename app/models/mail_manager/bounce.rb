=begin rdoc
Author::    Chris Hauboldt (mailto:biz@lnstar.com)
Copyright:: 2009 Lone Star Internet Inc.

Used to record messages which are returned to the configured account for 'bounce' in the config/config.yml, and pulled by BounceJob. Also responsible for knowing how to process a bounce by pulling diagnostic codes and a message's guid from the bounced email, unsubscribing users when necessary.

Diagnostic Codes:
5xx - will currently unsubscribe a contact, except when the error contains 'quota'
4xx - is ignored, and marked 'resolved' as they are temporary errors

Statuses:
'unprocessed' - initial status before processing
'needs_manual_intervention' - message identified by guid, but message not understood
'resolved' - message has been resolved during processing, and appropriate action taken
'invalid' - message not identified
'dismissed' - bounce has been dismissed by user
=end

module MailManager
  class Bounce < ActiveRecord::Base
    self.table_name = "#{MailManager.table_prefix}bounces"
    belongs_to :message, :class_name => 'MailManager::Message'
    belongs_to :mailing, :class_name => 'MailManager::Mailing', counter_cache: true
    include StatusHistory
    override_statuses(['needs_manual_intervention','unprocessed','dismissed','resolved','invalid','removed','deferred'],'unprocessed')
    before_create :set_default_status
    #default_scope :order => "#{MailManager.table_prefix}contacts.last_name, #{MailManager.table_prefix}contacts.first_name, #{MailManager.table_prefix}contacts.email_address",
    #    :joins => 
    #    "LEFT OUTER JOIN #{MailManager.table_prefix}messages on #{MailManager.table_prefix}bounces.message_id=#{MailManager.table_prefix}messages.id "+
    #    " LEFT OUTER JOIN #{MailManager.table_prefix}contacts on #{MailManager.table_prefix}messages.contact_id=#{MailManager.table_prefix}contacts.id"
#
    scope :by_mailing_id, lambda {|mailing_id| where(:mailing_id => mailing_id)}
    scope :by_status, lambda {|status| where(:status => status.to_s)}

    before_save :fix_counter_cache, if: lambda {|bounce| !bounce.new_record? && 
      bounce.mailing_id_changed?
    }

    attr_protected :id

    #Parses email contents for bounce resolution
    def process(force=false)
      if status.eql?('unprocessed') || force
        self.message = Message.find_by_guid(bounce_message_guid)
        self.mailing = message.mailing unless message.nil?
        if email.subject.to_s =~ /unsubscribe/i
          email.from.each do |email_address|
            MailManager::Subscription.unsubscribe_by_email_address(email_address)
          end
          change_status(:removed)
        elsif !from_mailer_daemon?
          change_status(:invalid)
        elsif delivery_error_code =~ /4\.\d\.\d/ || delivery_error_message.to_s =~ /quota/i
          update_attribute(:comments, delivery_error_message)
          change_status(:deferred)
        elsif delivery_error_code =~ /5\.\d\.\d/ && delivery_error_message.present?
          transaction do 
            update_attribute(:comments, delivery_error_message)
            change_status(:removed)
            if message.present?
              message.change_status(:failed)
              message.update_attribute(:result,"Failure Message from Bounce: #{delivery_error_message}")
            end
            Subscription.fail_by_email_address(contact_email_address)
          end
        else
          update_attribute(:comments, 'unrecognized diagnostic code')
          change_status(:needs_manual_intervention)
        end
        save
      end
    end

    def reprocess
      process(true)
    end

    def from_mailer_daemon?
      ['postmaster','mailer-daemon'].include?(email.from.first.gsub(/\@.*$/,'').downcase)
    rescue => e
      # they don't have a proper from email address
      delivery_error_code.present?
    end
  
    def dismiss
      raise "Status cannot be manually changed unless it needs manual intervention!" unless
        status.eql?('needs_manual_intervention')
      change_status(:dismissed)
    end
  
    def fail_address
      raise "Status cannot be manually changed unless it needs manual intervention!"  unless
        status.eql?('needs_manual_intervention')
      transaction do 
        Subscription.fail_by_email_address(contact_email_address) if contact.present?
        if message.present?
          message.result = message.result.to_s + "Failed by Administrator: (bounced, not auto resolved) "
          message.change_status(:failed)
        end
        change_status(:removed)
      end
    end

    def mailing_subject
      message.try(:mailing).try(:subject)
    end
  
    def subscription
      message.try(:subscription)
    end
    
    def contact
      message.try(:contact)
    end
  
    def contact_full_name
      contact.try(:full_name)
    end

    def contact_email_address
      if contact.blank?
        "Contact Deleted"
      else
        contact.email_address
      end
    end
  
    def delivery_error_code
      email.error_status
    rescue
      nil
    end

    def delivery_error_message
      email.diagnostic_code
    rescue
      nil
    end

    # Returns message guid 
    def bounce_message_guid
      email.to_s.gsub(/^.*X-Bounce-GUID:\s*([^\s]+).*$/mi,'\1') if email.to_s.match(/X-Bounce-GUID:\s*([^\s]+)/mi)
    end

    def email
      return @email if @email
      @email = Mail.new(bounce_message)
    end
  
   protected
    def fix_counter_cache
        MailManager::Mailing.decrement_counter(:bounces_count, self.mailing_id_was) if self.mailing_id_was.present?
        MailManager::Mailing.increment_counter(:bounces_count, self.mailing_id)
    end
  end
end
