class CommunityHubPluginPublicController < PublicController

	append_view_path File.join(File.dirname(__FILE__) + '/../../views')

	layout false


  def new_message
    if logged_in?

      begin
        hub = Article.find(params[:article_id])
      rescue
        hub = nil
      end

      if hub
        message_data = {}
        message_data.merge!(params[:message]) if params[:message]

        message = Comment.new(message_data)
        message.author = user
        message.title = message_timestamp
        message.article = hub
        message.ip_address = request.remote_ip
        message.user_agent = request.user_agent
        message.referrer = request.referrer

        if message && message.save
          render :text => {'ok' => true}.to_json, :content_type => 'application/json'
          return true
        end
      end

    end
    render :text => {'ok' => false}.to_json, :content_type => 'application/json'
  end


  def new_mediation
    if logged_in?

      begin
        profile = Profile.find(params[:profile_id])
      rescue
        profile = nil
      end

      if profile
        mediation_data = {}
        mediation_data.merge!(params[:article]) if params[:article]

        mediation = CommunityHubPlugin::Mediation.new(mediation_data)
        mediation.name = CommunityHubPlugin::Mediation.timestamp
        mediation.profile = profile
        mediation.last_changed_by = user
        mediation.created_by_id = user.id
        mediation.source = 'local'

        if mediation && mediation.save
          render :text => {'ok' => true}.to_json, :content_type => 'application/json'
          return true
        end
      end

    end
    render :text => {'ok' => false}.to_json, :content_type => 'application/json'
  end


  def newer_mediation_comment
    latest_id = params[:latest_post]
    mediation = params[:mediation]
    comments = Comment.find(:all, :conditions => ["id > :id and source_id = :mediation", { :id => latest_id, :mediation => mediation }])
    render :partial => "mediation_comment", :collection => comments
  end


	def newer_comments
		latest_post = params[:latest_post]
    hub = Article.find(params[:hub])
		posts = Comment.find(:all, :order => "id desc", :conditions => ["id > :id and source_id = :hub", { :id => latest_post, :hub => hub }], :limit => 30)

		if !posts.empty?
			oldest_post = posts.last.id
			latest_post = posts.first.id
      size = posts.size
		else
			oldest_post = 0
			latest_post = 0
		end

		render :partial => "post", :collection => posts, :locals => { :latest_id => latest_post, :oldest_id => oldest_post, :hub => hub }
	end


  def older_comments
    oldest_id = params[:oldest_id]
    hub = Article.find(params[:hub])
    posts = Comment.find(:all, :order => "id desc", :conditions => ["id < :id and source_id = :hub", { :id => oldest_id, :hub => hub }], :limit => 30)

    if !posts.empty?
      oldest_id = posts.last.id
      latest_id = posts.first.id
    end

    render :partial => "post", :collection => posts, :locals => { :latest_id => latest_id, :oldest_id => oldest_id, :hub => hub }
  end


  def newer_articles
    latest_post = params[:latest_post]
    hub = Article.find(params[:hub])
    posts = CommunityHubPlugin::Mediation.find(:all, :order => "id desc", :conditions => ["id > :id and parent_id = :hub", { :id => latest_post, :hub => hub.id }])

    if !posts.empty?
      oldest_post = posts.last.id
      latest_post = posts.first.id
    else
      oldest_post = 0
      latest_post = 0
    end

    render :partial => "mediation", :collection => posts, :locals => { :latest_post => latest_post, :oldest_post => oldest_post, :hub => hub }
  end


	def promote_user
    if logged_in?
      if (!params[:hub].blank? && !params[:user].blank?)
        begin
          hub = Article.find(params[:hub])
        rescue
          hub = nil
        end
        if hub && hub.mediator?(user)
          begin
            user_to_promote = Profile.find(params[:user])
          rescue
            user_to_promote = nil
          end
          if user_to_promote
            hub.mediators += [user_to_promote.id] unless hub.mediators.include?(user_to_promote.id)
            if hub.save
              render :text => {'ok' => true}.to_json, :content_type => 'application/json'
              return true
            end
          end
        end
      end
    end
    render :text => {'ok' => false}.to_json, :content_type => 'application/json'
	end


	def pin_message
    if logged_in?
      if (!params[:hub].blank? && !params[:message].blank?)

        begin
          hub = Article.find(params[:hub])
        rescue
          hub = nil
        end

        if hub && hub.mediator?(user)
          begin
            message = Comment.find(params[:message])
          rescue
            message = nil
          end

          if message
            author = message.author.blank? ? user : message.author

            mediation = CommunityHubPlugin::Mediation.new
            mediation.name = CommunityHubPlugin::Mediation.timestamp

            mediation.profile = hub.profile
            mediation.last_changed_by = author
            mediation.created_by_id = author.id
            mediation.body = message.body
            mediation.parent_id = hub.id
            mediation.source = 'local'

            if mediation && mediation.save

              if ( message.title == 'hub-message-twitter' )
                mediation.source = 'twitter'
                mediation.author_name = message.name
                mediation.profile_picture = message.profile_picture
                mediation.save
              end

              hub.pinned_messages += [message.id] unless hub.pinned_messages.include?(message.id)
              hub.pinned_mediations += [mediation.id] unless hub.pinned_mediations.include?(mediation.id)

              if hub && hub.save
                render :text => {'ok' => true}.to_json, :content_type => 'application/json'
                return true
              end

            end

          end
        end
      end
    end
    render :text => {'ok' => false}.to_json, :content_type => 'application/json'
	end


	protected

  def message_timestamp
    "hub-message-#{(Time.now.to_f * 1000).to_i}"
  end

end
