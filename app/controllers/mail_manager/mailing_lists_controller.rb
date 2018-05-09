module MailManager
  class MailingListsController < MailManager::ApplicationController
    include DeleteableActions
    def index
      @mailing_lists = MailingList.active.order("name asc").paginate(:page => params[:page])
    end

    def show
    end

    def new
      @mailing_list = MailingList.new
    end

    def edit
    end

    def create
      @mailing_list = MailingList.new(params[:mailing_list])
      if @mailing_list.save
        flash[:notice] = 'Mailing List was successfully created.'
        redirect_to(mail_manager.mailing_lists_path)
      else
        render :action => "new"
      end
    end

    def update
      if @mailing_list.update_attributes(params[:mailing_list])
        flash[:notice] = 'Mailing List was successfully updated.'
        redirect_to(mail_manager.mailing_lists_path)
      else
        render :action => "edit"
      end
    end

    def destroy
      @mailing_list.destroy
      flash[:notice] = "Mailing List was deleted."
      redirect_to(mail_manager.mailing_lists_url)
    end
  end
end
