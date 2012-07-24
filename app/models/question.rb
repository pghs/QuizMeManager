class Question < ActiveRecord::Base
	has_many :posts
  has_many :lessonaccesses

  def is_tweetable?
      return false if self.question =~ /image/ or self.question =~ /picture/
      return "#{self.question}".length + 14 < 141
  end


  def self.select_questions_to_post(current_acct, num_days_back_to_exclude)
    puts current_acct.inspect
    recent_question_ids = current_acct.posts.where("question_id is not null and created_at > ?", Date.today - num_days_back_to_exclude).order('created_at DESC').collect(&:question_id)
    recent_question_ids = recent_question_ids.empty? ? [0] : recent_question_ids
    access = Lessonaccess.where(:account_id => current_acct.id).collect(&:studyegg_id)
    access = access.empty? ? [0] : access
    questions = Question.where("studyegg_id in (?) and id not in (?)", access, recent_question_ids)

    q = questions.sample
    queue = []
    while queue.size < current_acct.posts_per_day
      if q.is_tweetable? && !queue.include?(q)
        puts 'added'
        queue << q
        q = questions.sample
      else
        puts 'finding new q'
        q = questions.sample
      end
    end
    PostQueue.enqueue_questions(current_acct, queue)
  end

  def self.post_question(current_acct, queue_index, shift)
    pq = PostQueue.find_by_account_id_and_index(current_acct.id, queue_index)
    return unless pq
    q_id = pq.question_id
    q = Question.find(q_id)
    puts "TWEET: #{q.question}"
    Post.tweet(current_acct, q.question, q.url, "initial#{shift}", q.id) if current_acct.twi_oauth_token
    puts "TUMBLR: #{q.question}"
    Post.create_tumblr_post(current_acct, q.question, q.url, "initial#{shift}", q.id) if current_acct.tum_oauth_token
  end


  ###THIS IS FOR IMPORTING FROM QUESTION BASE###
	require 'net/http'
  require 'uri'

  @qb = Rails.env.production? ? 'http://questionbase.studyegg.com' : 'http://localhost:3001'

  def self.get_public_with_lessons
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_public_with_lessons.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyeggs = JSON.parse(res.body)
    rescue
      studyeggs=[]
    end
    return studyeggs
  end
  
  def self.get_lesson_questions(lesson_id)
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{lesson_id}.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyegg = JSON.parse(res.body)
    rescue
      studyegg = nil
    end
    return studyegg
  end

  def self.get_lesson_details(lesson)
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_lesson_details/#{lesson}")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyeggs = JSON.parse(res.body)
    rescue
      studyeggs = []
    end
    return studyeggs
  end

  def self.get_studyegg_id_by_lesson_id(lesson_id)
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_id_by_chapter_id/#{lesson_id}.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyegg = res.body
    rescue
      studyegg=nil
    end
    return studyegg
  end

  def self.import_all_public_from_qb
    public_eggs = Question.get_public_with_lessons
    public_eggs.each do |p|
      p['chapters'].each do |ch|
        Question.save_lesson(ch, p['id'])
      end
    end
  end

  def self.import_lesson_from_qb(lesson_id)
    lesson = Question.get_lesson_details(lesson_id.to_s)
    egg_id = get_studyegg_id_by_lesson_id(lesson_id)
    puts egg_id
    lesson.each do |l|
      Question.save_lesson(l, egg_id)
    end
  end

  def self.save_lesson(ch, egg_id)
    @lesson_id = ch['id'].to_i
    puts @lesson_id
    if @lesson_id
      questions = Question.get_lesson_questions(@lesson_id)
      return if questions['questions'].nil?
      questions['questions'].each do |q|
        @q_id = q['id'].to_i
        @question = q['question']
        @answer = ''
        q['answers'].each do |a|
          @answer = a['answer'] if a['correct']
        end
        new_q = Question.find_by_q_id(@q_id)
        unless new_q
          Question.create(:q_id => @q_id, 
                          :lesson_id => @lesson_id, 
                          :studyegg_id => egg_id,
                          :question => Question.clean_and_clip_question(@question),
                          :answer => Question.clean_text(@answer),
                          :url => "http://www.studyegg.com/review/#{@lesson_id}/#{@q_id}")
        end
      end
    end
  end

  def self.clean_and_clip_question(quest)
    if quest[0..3].downcase=='true'
      i = quest.downcase.index('false')
      quest = "T\\F: "+ quest[(i+7)..-1]
    end
    clean_text(quest)
  end

  def self.clean_text(a)
    a.gsub!('<sub>','')
    a.gsub!('</sub>','')
    a.gsub!('<sup>-</sup>','-')
    a.gsub!('<sup>+</sup>','+')
    a.gsub!('<sup>','^')
    a.gsub!('</sup>','')
    a
  end
end
