=begin rdoc
Author::    Chris Hauboldt (mailto:biz@lnstar.com)
Copyright:: 2009 Lone Star Internet Inc.

This class is responsible for actually sending email messages... its mostly just an ActionMailer, but also has the added functionality to send messages with inline images.

Messages:
unsubscribed - sends an email to notify the user that they have been removed
message - sends and Message 
test_mailing - sends a test message for a mailing
mail - knows how to send any message based on the different "mime" parts its given

=end

require 'open-uri'
require "base64"
begin
  require "mini_magick" 
rescue => e
  # :nocov:
  require 'rmagick' rescue nil
  # :nocov:
end


module MailManager
  class Mailer < ActionMailer::Base
    # send a confirmation email for unsubscribing
    def unsubscribed(subscriptions,email_address,contact=nil,message=nil)
      @contact = contact
      @email_address = email_address
      @recipients = @email_address
      @from = message.try(:from_email_address) || MailManager.default_from_email_address
      @mailing_lists = subscriptions.reject{|subscription| subscription.mailing_list.nil?}.
        collect{|subscription| subscription.mailing_list.name}
      @subject = "Unsubscribed from #{@mailing_lists.join(',')} at #{MailManager.site_url}"
      Rails.logger.debug "Really Sending Unsubscribed from #{@mailing_lists.first} to #{@email_address}"
      mail(to: @recipients, from: @from, subject: @subject)
    end

    def double_opt_in(contact)
      @contact = contact
      @recipients = @contact.email_address
      @subject = "Confirm Newsletter Subscription at #{::MailManager.site_url}"
      @from = ::MailManager.signup_email_address
      @mailing_list_names = contact.subscriptions.map(&:mailing_list).map(&:name).join(', ')
      @headers    = {'Return-Path' => ::MailManager.bounce['email_address']}
      mail(to: @recipients, from: @from, subject: @subject)
    end

    class << self
      # send a mailing related to the message's data
      def deliver_message(message, cached_parts=nil)
        cached_parts ||= message.parts
        self.send_mail(message.subject,message.email_address_with_name,message.from_email_address,
          cached_parts,message.guid,message.mailing.include_images?,message.unsubscribe_url)
      end

      # create mailing; parsing html sources for images to attach/include
      def multipart_with_inline_images(subject,to_email_address,from_email_address,the_parts,message_id=nil,include_images=true)
        text_source = the_parts.first[1];nil
        original_html_source = the_parts.last[1];nil
        mail = Mail.new do
          to            to_email_address
          from          from_email_address
          subject       subject
          part :content_type => "multipart/alternative", :content_disposition => "inline" do |main|
            main.part :content_type => "text/plain", :body => text_source
            if include_images
              main.part :content_type => "multipart/related" do |related|
                (html_source,images) = MailManager::Mailer::inline_html_with_images(original_html_source)
                images.each_with_index do |image,index|
                  related.attachments.inline[image[:filename]] = {
                    :content_id => image[:cid],
                    :content => image[:content]
                  }
                  html_source.gsub!(image[:cid],related.attachments[index].cid)
                end
                related.part :content_type => "text/html; charset=UTF-8", :body => html_source
              end
            else
              main.part :content_type => "text/html; charset=UTF-8", :body => original_html_source
            end
          end
        end
        mail
      end

      # create mailing without fetching image data
      def multipart_alternative_without_images(subject,to_email_address,from_email_address,the_parts,message_id=nil,include_images=true)
        text_source = the_parts.first[1];nil
        original_html_source = the_parts.last[1];nil
        mail = Mail.new do
          to            to_email_address
          from          from_email_address
          subject       subject

          text_part do
            body text_source
          end

          html_part do
            content_type 'text/html; charset=UTF-8'
            body original_html_source
          end
        end
        mail
      end
    
      # send the mailing with the given subject, addresses, and parts
      def send_mail(subject,to_email_address,from_email_address,the_parts,message_id=nil,include_images=true,unsubscribe_url=nil)
        include_images = (include_images and !MailManager.dont_include_images_domains.detect{|domain| 
          to_email_address.strip =~ /#{domain}>?$/})
        mail = if include_images
          multipart_with_inline_images(subject,to_email_address,from_email_address,the_parts,message_id,include_images)
        else
          multipart_alternative_without_images(subject,to_email_address,from_email_address,the_parts,message_id,include_images)
        end
        mail.header['Return-Path'] = MailManager.bounce['email_address']
        mail.header['X-Bounce-Guid'] = message_id if message_id
        unsubscribe_header = "<mailto:#{MailManager.bounce['email_address']}?subject=unsubscribe>"
        unsubscribe_header += ",<#{unsubscribe_url}>" if unsubscribe_url.present? 
        mail.header['List-Unsubscribe'] = unsubscribe_header
        set_mail_settings(mail)
        mail.deliver!
        Rails.logger.info "Sent mail to: #{to_email_address}"
        Rails.logger.debug mail.to_s
      end

      # set mail delivery settings
      def set_mail_settings(mail)
        delivery_method = ActionMailer::Base.delivery_method
        delivery_method = delivery_method.eql?(:letter_opener) ? :test : delivery_method
        mail.delivery_method delivery_method
        # letter opener blows up!
        # Ex set options!
        #         mail.delivery_method.settings.merge!( {
        #   user_name: 'bobo',
        #   password: 'Secret1!',
        #   address: 'mail.lnstar.com',
        #   domain: 'mail.lnstar.com',
        #   enable_starttls_auto: true,
        #   authentication: :plain,
        #   port: 587
        # } )

        mail.delivery_method.settings.merge!(
          (case delivery_method 
           when :smtp then ActionMailer::Base.smtp_settings
           # :nocov:
           when :sendmail then ActionMailer::Base.sendmail_settings
           # :nocov:
           else
             {}
           end rescue {})
        )
      end
    
      # return mime type for images by extension
      def image_mime_types(extension)
        # :nocov:
        case extension.downcase
          when 'bmp' then 'image/bmp'
          when 'cod' then 'image/cis-cod'
          when 'gif' then 'image/gif'
          when 'ief' then 'image/ief'
          when 'jpe' then 'image/jpeg'
          when 'jpeg' then 'image/jpeg'
          when 'jpg' then 'image/jpeg'
          when 'png' then 'image/png'
          when 'jfif' then 'image/pipeg'
          when 'svg' then 'image/svg+xml'
          when 'tif' then 'image/tiff'
          when 'tiff' then 'image/tiff'
        end
        # :nocov:
      end
      
      # find the extension for images by inspecting their data
      def get_extension_from_data(image_data)
        if defined?(MiniMagick)
          format = ''
          file = Tempfile.new('get-extension','tmp')
          file.close
          File.open(file.path,'wb'){|binfile| binfile.write(image_data)}
          MiniMagick::Image.open(file.path)[:format] || ''
        elsif defined?(Magick)
          # :nocov: currently on ly mini_magick is tested
          Magick::Image.from_blob(image_data).first.format || ''
          # :nocov:
        else
          ''
        end
      rescue => e
        ''
      end
    

      # parses html and retrieves images and inserts them with CID/attachments
      def inline_html_with_images(html_source)
        parsed_data = html_source.split(/(<\s*img[^>]+src\s*=\s*["'])([^"']*)(["'])/i)
        images = Array.new
        final_html = ''
        image_errors = ''
        parsed_data.each_with_index do |data,index|
          if(index % 4 == 2)
            image = Hash.new()
            image[:cid] = Base64.encode64(data).gsub(/\s*/,'').reverse[0..59]
            if images.detect{|this_image| this_image[:cid].eql?(image[:cid])}
              final_html << "cid:#{image[:cid]}"
              next
            end
            #only attach new images!
            begin
              image[:content] = fetch(data)
            rescue => e
              image_errors += "\n  Couldn't fetch url '#{data}'<!--, #{e.message} - #{e.backtrace.join("\n")}-->\n"
            end
            if image[:content].blank?
              final_html << data
              next
            end
            image[:filename] = filename = File.basename(data)
            extension = filename.gsub(/^.*\./,'').downcase
            Rails.logger.debug "Fetching Image for: #{filename} #{image[:content].to_s[0..30]}"
            extension = get_extension_from_data(image[:content]) if image_mime_types(extension).blank?
            image_errors += "\n  Couldn't find mime type for #{extension} on #{data}" if image_mime_types(extension).blank?
            image[:content_type] = image_mime_types(extension)
            final_html << "cid:#{image[:cid]}"
            images << image
          else
            final_html << data
          end
        end
        # FIXME: add warnings for missing images email or on the newsletter/mailing page
        # raise image_errors unless image_errors.eql?('')
        [final_html,images]
      end

      # fetch the data from a url (used for images) 
      def fetch(uri_str, limit = 10)
        uri = URI.parse(uri_str)
        if uri.scheme.eql?('file')
          File.binread(uri_str.gsub(%r#^file://#,''))
        else
          uri.read
        end
      end
    end
  end
end



