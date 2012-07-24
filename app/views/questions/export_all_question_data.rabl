collection @questions

attributes :id, :question, :lesson_id, :studyegg_id, :q_id, :url

child(:posts) do
  	attributes :id, :account_id, :question_id, :provider, :text, :url, :link_type, :post_type, :provider_post_id, :created_at, :updated_at, :to_twi_user_id
	
	child(:mentions) do
	  attributes :id, :user_id, :post_id, :text, :responded, :first_answer, :correct, :twi_tweet_id, :twi_in_reply_to_status_id, :created_at, :updated_at, :sent_date

		child(:user) do
	  	attributes :id, :twi_name, :twi_screen_name, :twi_user_id, :twi_profile_img_url
	  end
	end
end