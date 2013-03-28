module MailMgr
  class MailingsController < ApplicationController
    layout 'admin'
    before_filter :find_mailing, :except => [:new,:create,:index]
    before_filter :find_all_mailing_lists, :only => [:new,:create,:edit,:update]
    before_filter :find_mailables, :only => [:new,:create,:edit,:update]
    before_filter :get_mailables_for_select, :only => [:new,:create,:edit,:update]

    def index
      @mailings = Mailing.all.sort_by{|mailing| mailing.created_at}.reverse
    end

    def show
    end

    def new
      @mailing = Mailing.new
      @mailing.from_email_address = Conf.mail_mgr_default_from_email_address if Conf.mail_mgr_default_from_email_address
      @mailing.scheduled_at = Time.now
      @mailing.include_images = true
      @mailing.mailing_lists = @all_mailing_lists
    end

    def edit
    end
  
    def test
    end
  
    def schedule
      @mailing.schedule
      redirect_to mail_mgr_mailings_path
    rescue => e
      flash[:error] = e.message
      redirect_to mail_mgr_mailings_path
    end
  
    def cancel
      @mailing.cancel
      flash[:notice] = 'Mailing was successfully canceled and set to pending.  Be sure to reschedule or remove your mailing.'
      redirect_to mail_mgr_mailings_path
    end
  
    def resume
      @mailing.resume
      redirect_to mail_mgr_mailings_path
    end
  
    def pause
      @mailing.pause
      redirect_to mail_mgr_mailings_path
    end
  
    def send_test
      @mailing.send_test_message(params[:test_email_addresses])
      flash[:notice] = "Test messages sent to #{params[:test_email_addresses]}."
      redirect_to mail_mgr_mailings_path
    end

    def create
      @mailing = Mailing.new(params[:mail_mgr_mailing])
      if @mailing.save
        flash[:notice] = 'Mailing was successfully created.'
        redirect_to(mail_mgr_mailings_path)
      else
        render :action => "new"
      end
    end

    def update
      if @mailing.update_attributes(params[:mail_mgr_mailing])
        flash[:notice] = 'Mailing was successfully updated.'
        redirect_to(mail_mgr_mailings_path)
      else
        render :action => "edit"
      end
    end

    def destroy
      @mailing.destroy
      redirect_to(mail_mgr_mailings_url)
    end
  
    protected
  
    def find_mailing
      @mailing = Mailing.find(params[:id])
    end
  
    def find_all_mailing_lists
      @all_mailing_lists = MailingList.active.find(:all, :order => "name asc")
    end
  
    def find_mailables
      @mailables = MailableRegistry.find
    end
  
    def get_mailables_for_select
      #@mailables_for_select = [['Choose Mailable', @mailable.is_a?(Mailable)  ? 
      #  'Mailable_new' : '']]+@mailables.collect{|mailable| 
      #  [mailable.name,"#{mailable.class.name}_#{mailable.id}"]}
      @mailables_for_select = @mailables.collect{|mailable| 
        [mailable.name,"#{mailable.class.name}_#{mailable.id}"]}
    end
  end
end
