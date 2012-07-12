class Account < ActiveRecord::Base
	has_many :posts
	has_many :questions, :through => :lessonaccess

	def twitter
		if self.twi_oauth_token and self.twi_oauth_secret
			client = Twitter::Client.new(:consumer_key => SERVICES['twitter']['key'],
																 :consumer_secret => SERVICES['twitter']['secret'],
																 :oauth_token => self.twi_oauth_token,
																 :oauth_token_secret => self.twi_oauth_secret)
		end
		client
	end
end
