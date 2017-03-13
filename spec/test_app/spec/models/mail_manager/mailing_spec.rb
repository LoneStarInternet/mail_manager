require 'rails_helper'

class MyMailable < MailManager::Mailable
  cattr_accessor :mailable_parts_call_count
  def initialize(*args)
    @@mailable_parts_call_count = 0
    super
  end

  def mailable_parts
    @@mailable_parts_call_count += 1
    super
  end
end
RSpec.describe MailManager::Mailing do
  let(:valid_attributes) {FactoryGirl.attributes_for(:mailing)}
  let(:invalid_attributes) {FactoryGirl.attributes_for(:mailing).delete(
    'from_email_address')
  }
  before(:each) do
    ActionMailer::Base.delivery_method = :test
    Delayed::Worker.delay_jobs = false
    ActionMailer::Base.deliveries.clear
  end
  it "allows a processing mailing to run(for resetting a failed job)" do
    mailing = MailManager::Mailing.create(valid_attributes)
    mailing.change_status(:processing)
    expect(mailing.can_run?).to be true
  end
  it "sets its initial status properly" do
    attributes = valid_attributes
    attributes.delete('status')
    attributes.delete('status_updated_at')
    mailing = MailManager::Mailing.new(attributes)
    mailing.save
    expect(mailing.status.to_s).to eq('pending')
    expect(mailing.status_changed_at).not_to be nil
  end
  it "will soft delete a mailing" do
    mailing = MailManager::Mailing.create(valid_attributes)
    mailing.delete
    expect(MailManager::Mailing.count).to eq 0
    expect(MailManager::Mailing.deleted.count).to eq 1
  end
  it "will remove the scheduled job on deletion" do
    Delayed::Job.delete_all
    expect(Delayed::Job.count).to eq 0
    Delayed::Worker.delay_jobs = true
    mailing = MailManager::Mailing.create(valid_attributes.merge({
      scheduled_at: 4.hours.from_now
    }))
    mailing.schedule
    expect(Delayed::Job.count).to eq 1
    expect(mailing.job).to eq Delayed::Job.first
    mailing.delete
    expect(MailManager::Mailing.deleted.count).to eq 1
    expect(Delayed::Job.count).to eq 0
    Delayed::Worker.delay_jobs = false
  end
  it "doesn't include images when configured to not do so for a domain" do
    # should be in config
    image_url = "http://www.lone-star.net/graphics/lst_header_logo.png"
    expect(MailManager.dont_include_images_domains).to include('yahoo.com')
    mailing = FactoryGirl.create(:mailing, include_images: true)
    mailing.mailable.update_attribute(:email_html, mailing.mailable.email_html.gsub(%r#file://.*/iReach_logo.gif#,image_url))
    mailing.send_test_message('bobo@yahoo.com')
    html_body = ActionMailer::Base.deliveries.last.parts.last.body
    expect(html_body).to match /#{image_url}/
    expect(html_body).not_to match %r#cid:#
  end
  it "doesn't include images when include_images is false" do
    # should be in config
    image_url = "http://www.lone-star.net/graphics/lst_header_logo.png"
    expect(MailManager.dont_include_images_domains).to include('yahoo.com')
    mailing = FactoryGirl.create(:mailing, include_images: false)
    mailing.mailable.update_attribute(:email_html, mailing.mailable.email_html.gsub(%r#file://.*/iReach_logo.gif#,image_url))
    mailing.send_test_message('bobo@example.com')
    html_body = ActionMailer::Base.deliveries.last.parts.last.body
    expect(html_body).to match /#{image_url}/
    expect(html_body).not_to match %r#cid:#
  end
  it "does include images when its configuration doesn't exclude an email domain" do
    image_url = "http://www.lone-star.net/graphics/lst_header_logo.png"
    expect(MailManager.dont_include_images_domains).not_to include('example.com')
    mailing = FactoryGirl.create(:mailing, include_images: true)
    mailing.mailable.update_attribute(:email_html, mailing.mailable.email_html.gsub(%r#file://.*/iReach_logo.gif#,image_url))
    mailing.send_test_message('bobo@example.com')
    html_body = ActionMailer::Base.deliveries.last.to_s
    expect(html_body).to match /cid:=/
  end

  it "works for https images" do
    pending "test https images!"
    raise "BLARG!"
  end

  it "doesn't blow up when images are missing" do
    image_url = "http://www.lone-star.net/graphics/not_here.png"
    mailing = FactoryGirl.create(:mailing, include_images: true)
    mailing.mailable.update_attribute(:email_html, mailing.mailable.email_html.gsub(%r#file://.*/iReach_logo.gif#,image_url))
    mailing.send_test_message('bobo@example.com')
    expect(ActionMailer::Base.deliveries.length).to eq 1 
    html_body = ActionMailer::Base.deliveries.last.to_s 
    expect(html_body).not_to match /cid:=/
    expect(html_body).to include image_url
  end

  it "includes emails from its lists" do
    contact1 = FactoryGirl.create(:contact)
    contact2 = FactoryGirl.create(:contact)
    contact3 = FactoryGirl.create(:contact)
    contact4 = FactoryGirl.create(:contact)
    list1 = FactoryGirl.create(:mailing_list)
    contact1.subscribe(list1)
    contact2.subscribe(list1)
    list2 = FactoryGirl.create(:mailing_list)
    contact2.subscribe(list2)
    contact3.subscribe(list2)
    list3 = FactoryGirl.create(:mailing_list)
    contact3.subscribe(list3)
    contact4.subscribe(list3)
    contact3.unsubscribe(list2)
    mailing = FactoryGirl.create(:mailing)
    mailing.mailing_lists << list1
    mailing.mailing_lists << list2
    mailing.initialize_messages
    mailing.reload
    expect(mailing.messages.map(&:email_address).sort).to eq (
      [contact1,contact2].map(&:email_address).sort
    )
  end

  context "when sending a mailing" do
    before(:each) do
      if MailManager.register_generic_mailable
        MailManager::MailableRegistry.register('MyMailable',{
          :find_mailables => :all,
          :name => :name,
          :parts => [
            ['text/plain', :email_text],
            ['text/html', :email_html]
        ]
        })
      end
      Delayed::Worker.delay_jobs = true
      @list = FactoryGirl.create(:mailing_list)
      @contacts = FactoryGirl.create_list(:contact,random_int(4,10))
      @contacts.each{|c| c.subscribe(@list)}
      @mailable = MyMailable.create(FactoryGirl.attributes_for(:mailable))
      @mailing = FactoryGirl.create(:mailing, mailable: @mailable)
      @mailing.mailable = @mailable
      @mailing.mailing_lists << @list
      @mailing.schedule
    end
    after(:each) do
      Delayed::Worker.delay_jobs = false
      MailManager::MailableRegistry.unregister('MyMailable')
    end
    it "caches its mailable for use between messages" do
      MyMailable.mailable_parts_call_count = 0
      @mailing.deliver
      expect(MyMailable.mailable_parts_call_count).to eq 1
    end

    it "sends a specified number of messages per job" do
      expect(Delayed::Job.count).to eq 1
      expect(MailManager.deliveries_per_run).to be > 0
      MailManager.deliveries_per_run = 2
      ActionMailer::Base.deliveries.clear
      @mailing.deliver
      expect(@mailing.status.to_s).to eq 'processing'
      expect(Delayed::Job.count).to eq 2
      expect(ActionMailer::Base.deliveries.count).to eq 2
      expect(@mailing.messages.pending.count).to eq (@contacts.count - 2)
    end
    it 'finishes the mailing' do
      MailManager.deliveries_per_run = 2
      ActionMailer::Base.deliveries.clear
      while ['scheduled','processing'].include?(@mailing.status) do
        @mailing.deliver
      end
      expect(Delayed::Job.count).to eq (@contacts.count/2.0).ceil
      expect(@mailing.status.to_s).to eq 'completed'
      expect(ActionMailer::Base.deliveries.count).to eq @contacts.count
    end
  end
end
