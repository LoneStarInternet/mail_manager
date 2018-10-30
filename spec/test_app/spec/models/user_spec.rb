require 'rails_helper'

RSpec.describe User do
  context "when valid" do
    before(:each) do
      @user = FactoryGirl.build(:user)
    end
    it "should have a uniq email" do
      @user.save
      @user2 = FactoryGirl.build(:user, {email: @user.email})
      expect(@user2.valid?).to eq false
    end
    it "should have an email" do
      expect(@user.valid?).to eq true
      @user.email = nil
      expect(@user.valid?).to eq false
    end
  end
  context "integrated with mail manager" do
    before(:each) do
      @user = FactoryGirl.create(:user)
    end
    it "should respond to subscriptions" do
      expect(@user.respond_to?(:subscriptions)).to eq true
    end
    it "should have a contact" do
      expect(@user.contact.present?).to eq true
    end
    it "should have the same email as the contact" do
      expect(@user.email).to eq @user.contact.email_address
    end
    it "should be able to subscribe to a mailing list" do 
      @mailing_list = FactoryGirl.create(:mailing_list)
      @user.subscribe(@mailing_list)
      @user.reload
      expect(@user.subscriptions.detect(&:active?).mailing_list).to eq(@mailing_list)
    end
    it "soft deletes its contact when it is destroyed" do
      contact = @user.contact
      @user.destroy
      expect(MailManager::Contact.deleted.where(id: contact.id).count).to eq 1
      expect(MailManager::Contact.where(id: contact.id).count).to eq 0
    end
  end
end
