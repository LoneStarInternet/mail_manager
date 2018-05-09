=begin rdoc
Author::    Chris Hauboldt (mailto:biz@lnstar.com)
Copyright:: 2009 Lone Star Internet Inc.

MailingList simply defines the available lists for subscriptions in the system. See Subscription for more information.

=end
module MailManager
  class MailingList < ActiveRecord::Base

    self.table_name =  "#{MailManager.table_prefix}mailing_lists"
    
    # associations get stupid when ActiveRecord is scoped for some horrible reason
    has_many :subscriptions, :class_name => 'MailManager::Subscription'
    has_and_belongs_to_many :mailings, :class_name => 'MailManager::Mailing',
      :join_table => "#{MailManager.table_prefix}mailing_lists_#{MailManager.table_prefix}mailings"
  
    scope :active, {:conditions => {:status => 'active',:deleted_at => nil}}

    validates :name, presence: true
  
    include StatusHistory
    include Deleteable if (column_names.include?('deleted_at') rescue false)
    before_create :set_default_status

    attr_protected :id

    # custom query to efficiently retrieve the active email addresses and contact ids and subscription ids for a 
    # given list of mailing lists
    def self.active_email_addresses_contact_ids_subscription_ids_for_mailing_list_ids(mailing_list_ids)
      results = MailManager::MailingList.connection.execute(
        %Q|select c.email_address as email_address, c.id as contact_id, 
        s.id as subscription_id from #{MailManager.table_prefix}contacts c 
        inner join #{MailManager.table_prefix}subscriptions s on c.id=s.contact_id 
        where s.status in ('active') and c.deleted_at is NULL and mailing_list_id in (#{
        mailing_list_ids.map(&:to_i).uniq.join(',')})|
      )
      results = results.map(&:values) if results.first.is_a?(Hash)
      results.inject(Hash.new){ |h,r|
        h.merge!(r[0].to_s.strip.downcase => {
          contact_id: r[1].to_i, subscription_id: r[2].to_i
        })
      }
    end

    # whether or not the mailing list has been soft deleted 
    def active?
      deleted_at.nil?
    end
    
    # whether or not the mailing list has been soft deleted 
    def inactive?
      !active?
    end
  
  end
end
