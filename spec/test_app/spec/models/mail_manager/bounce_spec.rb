# encoding: utf-8
require 'rails_helper'

RSpec.describe MailManager::Bounce do
  context "when checking pop account" do
    it "should not blow up when mail has no from address" do
      Delayed::Worker.delay_jobs = true
      send_bounce('bounce-500-no-from-address.eml')
      MailManager::BounceJob.new.perform
      expect(MailManager::Bounce.last.message.status).to eq 'failed'
      Delayed::Worker.delay_jobs = false
    end
    it "should not blow up when mail contains a bad extended char" do
      Delayed::Worker.delay_jobs = true
      send_bounce('bad_utf8_chars.eml')
      MailManager::BounceJob.new.perform
      Delayed::Worker.delay_jobs = false
    end
    it "should run every 10 minutes when there is mail on the current run" do
      Delayed::Worker.delay_jobs = true
      send_bounce('bad_utf8_chars.eml')
      MailManager::BounceJob.new.perform
      expect(Delayed::Job.count).to eq(1)
      expect(Delayed::Job.first.run_at.utc.to_i).to be_within(5).of(
        10.minutes.from_now.utc.to_i
      )
      Delayed::Worker.delay_jobs = false
    end
    it "should run every 120 minutes when there is no mail on the current check" do
      Delayed::Worker.delay_jobs = true
      MailManager::BounceJob.new.perform
      Delayed::Job.delete_all
      MailManager::BounceJob.new.perform
      expect(Delayed::Job.count).to eq(1)
      expect(Delayed::Job.first.run_at.utc.to_i).to be_within(5).of(
        120.minutes.from_now.utc.to_i
      )
      Delayed::Worker.delay_jobs = false
    end

    it "deferred's 400's" do
      bounce = MailManager::Bounce.create(
        bounce_message: File.read('spec/support/files/bounce-400.txt')
      )
      bounce.process
      expect(bounce.status).to eq 'deferred'
    end

    it "removed's 500's and 'failed_address's associated active subscriptions" do
      contact = FactoryGirl.create(:contact)
      mailing_list = FactoryGirl.create(:mailing_list)
      mailing_list2 = FactoryGirl.create(:mailing_list)
      sub1=contact.subscribe(mailing_list)
      mailing = FactoryGirl.create(:mailing)
      message = FactoryGirl.create(:message, 
        mailing_id: mailing.id,
        contact_id: contact.id
      )
      bounce_guid = '30-28-11376-fa351cf35e4012d37d8c13df8735fd13edfed563'

      bounce = MailManager::Bounce.create(
        bounce_message: File.read('spec/support/files/bounce-500.txt').gsub(
        /#{bounce_guid}/,message.guid)
      )
      bounce.process
      sub1.reload
      expect(bounce.status).to eq 'removed'
      expect(sub1.status).to eq 'failed_address'
      expect(MailManager::Subscription.count).to eq 1
    end
  end
  def send_bounce(filename)
    mail = Mail.new(File.read(File.join(Rails.root,'spec','support','files',filename)))
    mail.delivery_method :smtp
    mail.delivery_method.settings.merge!(ActionMailer::Base.smtp_settings)
    mail.deliver
  end
end
