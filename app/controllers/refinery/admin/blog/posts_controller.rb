module Refinery
  module Admin
    module Blog
      class PostsController < ::Refinery::AdminController

        cache_sweeper Refinery::BlogSweeper

        crudify :'refinery/blog/post',
                :title_attribute => :title,
                :order => 'published_at DESC',
                :redirect_to_url => "main_app.refinery_admin_blog_posts_path"

        before_filter :find_all_categories,
                      :only => [:new, :edit, :create, :update]

        before_filter :check_category_ids, :only => :update

        def uncategorized
          @blog_posts = Refinery::Blog::Post.uncategorized.page(params[:page])
        end

        def tags
          if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
            op = '~*'
            wildcard = '.*'
          else
            op = 'LIKE'
            wildcard = '%'
          end

          @tags = Refinery::Blog::Post.tag_counts_on(:tags).where(
              ["tags.name #{op} ?", "#{wildcard}#{params[:term].to_s.downcase}#{wildcard}"]
            ).map { |tag| {:id => tag.id, :value => tag.name}}
          render :json => @tags.flatten
        end

        def create
          # if the position field exists, set this object as last object, given the conditions of this class.
          if Refinery::Blog::Post.column_names.include?("position")
            params[:blog_post].merge!({
              :position => ((Refinery::Blog::Post.maximum(:position, :conditions => "")||-1) + 1)
            })
          end

          if Refinery::Blog::Post.column_names.include?("user_id")
            params[:blog_post].merge!({
              :user_id => current_refinery_user.id
            })
          end

          if (@blog_post = Refinery::Blog::Post.create(params[:blog_post])).valid?
            (request.xhr? ? flash.now : flash).notice = t(
              'refinery.crudify.created',
              :what => "'#{@blog_post.title}'"
            )

            unless from_dialog?
              unless params[:continue_editing] =~ /true|on|1/
                redirect_back_or_default(main_app.refinery_admin_blog_posts_path)
              else
                unless request.xhr?
                  redirect_to :back
                else
                  render :partial => "/shared/message"
                end
              end
            else
              render :text => "<script>parent.window.location = '#{admin_blog_posts_url}';</script>"
            end
          else
            unless request.xhr?
              render :action => 'new'
            else
              render :partial => "/refinery/admin/error_messages",
                     :locals => {
                       :object => @blog_post,
                       :include_object_name => true
                     }
            end
          end
        end

      protected
        def find_all_categories
          @blog_categories = Refinery::Blog::Category.find(:all)
        end

        def check_category_ids
          params[:blog_post][:category_ids] ||= []
        end
      end
    end
  end
end
